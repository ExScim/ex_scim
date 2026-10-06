defmodule ExScimPhoenix.Controller.BulkControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias ExScimPhoenix.Test.TestStorage

  @endpoint ExScimPhoenix.Test.Endpoint

  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"
  @bulk_request_schema "urn:ietf:params:scim:api:messages:2.0:BulkRequest"
  @bulk_response_schema "urn:ietf:params:scim:api:messages:2.0:BulkResponse"
  @error_schema "urn:ietf:params:scim:api:messages:2.0:Error"

  setup do
    {:ok, _} = TestStorage.start_link()
    prev_storage = Application.get_env(:ex_scim, :storage_strategy)
    prev_auth = Application.get_env(:ex_scim, :auth_provider_adapter)
    prev_lifecycle = Application.get_env(:ex_scim, :lifecycle_adapter)
    prev_max_payload = Application.get_env(:ex_scim, :bulk_max_payload_size)
    prev_max_operations = Application.get_env(:ex_scim, :bulk_max_operations)

    Application.put_env(:ex_scim, :storage_strategy, TestStorage)
    Application.put_env(:ex_scim, :auth_provider_adapter, ExScimPhoenix.Test.TestAuth)
    Application.delete_env(:ex_scim, :lifecycle_adapter)

    on_exit(fn ->
      restore(:storage_strategy, prev_storage)
      restore(:auth_provider_adapter, prev_auth)
      restore(:lifecycle_adapter, prev_lifecycle)
      restore(:bulk_max_payload_size, prev_max_payload)
      restore(:bulk_max_operations, prev_max_operations)
      TestStorage.stop()
    end)

    :ok
  end

  describe "POST /Bulk" do
    test "processes a valid bulk request and returns 200 with per-operation results" do
      request = bulk_request([post_op("q1", "alice")])

      conn = post(auth_conn(), "/Bulk", request)
      body = json_response(conn, 200)

      assert body["schemas"] == [@bulk_response_schema]
      assert [op] = body["Operations"]
      assert op["status"] == "201"
      assert op["bulkId"] == "q1"
      assert op["location"] == op["response"]["meta"]["location"]
      assert op["location"] =~ "/scim/v2/Users/#{op["response"]["id"]}"
    end

    test "processes multiple operations" do
      request = bulk_request([post_op("q1", "alice"), post_op("q2", "bob")])

      conn = post(auth_conn(), "/Bulk", request)
      body = json_response(conn, 200)

      assert length(body["Operations"]) == 2
      assert Enum.all?(body["Operations"], &(&1["status"] == "201"))
    end

    test "rejects a request with an invalid schema (400)" do
      request = %{"schemas" => ["wrong"], "Operations" => [post_op("q1", "alice")]}

      conn = post(auth_conn(), "/Bulk", request)
      body = json_response(conn, 400)

      assert body["schemas"] == [@error_schema]
      assert body["scimType"] == "invalidSyntax"
    end

    test "rejects a request missing Operations (400)" do
      request = %{"schemas" => [@bulk_request_schema]}

      conn = post(auth_conn(), "/Bulk", request)
      assert json_response(conn, 400)["scimType"] == "invalidSyntax"
    end

    test "respects failOnErrors and stops after the limit" do
      # Two invalid operations (missing userName -> create fails). With
      # failOnErrors: 1, processing stops after the first error, so only one
      # operation result is returned.
      bad_op = fn id ->
        %{
          "method" => "POST",
          "bulkId" => id,
          "path" => "/Users",
          "data" => %{"schemas" => [@user_schema]}
        }
      end

      request = bulk_request([bad_op.("q1"), bad_op.("q2")]) |> Map.put("failOnErrors", 1)

      conn = post(auth_conn(), "/Bulk", request)
      body = json_response(conn, 200)

      assert length(body["Operations"]) == 1
      assert hd(body["Operations"])["status"] != "201"
    end

    test "payload over the configured max returns 413" do
      Application.put_env(:ex_scim, :bulk_max_payload_size, 10)
      request = bulk_request([post_op("q1", "alice")])

      conn = post(auth_conn(), "/Bulk", request)
      body = json_response(conn, 413)

      refute Map.has_key?(body, "scimType")
      assert body["detail"] =~ "Payload too large"
    end

    test "operations over the configured max returns 413" do
      Application.put_env(:ex_scim, :bulk_max_operations, 1)
      request = bulk_request([post_op("q1", "alice"), post_op("q2", "bob")])

      conn = post(auth_conn(), "/Bulk", request)
      body = json_response(conn, 413)

      refute Map.has_key?(body, "scimType")
      assert body["detail"] =~ "Too many operations"
    end

    test "requires authentication" do
      request = bulk_request([post_op("q1", "alice")])

      conn =
        post(
          build_conn() |> put_req_header("content-type", "application/scim+json"),
          "/Bulk",
          request
        )

      assert json_response(conn, 401)["schemas"] == [@error_schema]
    end
  end

  # --- helpers ---

  defp bulk_request(operations) do
    %{"schemas" => [@bulk_request_schema], "Operations" => operations}
  end

  defp post_op(bulk_id, user_name) do
    %{
      "method" => "POST",
      "bulkId" => bulk_id,
      "path" => "/Users",
      "data" => %{
        "schemas" => [@user_schema],
        "userName" => user_name,
        "name" => %{"givenName" => "Test", "familyName" => "User"}
      }
    }
  end

  defp auth_conn(token \\ "token-all") do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/scim+json")
    |> put_req_header("accept", "application/scim+json")
  end

  defp restore(key, nil), do: Application.delete_env(:ex_scim, key)
  defp restore(key, value), do: Application.put_env(:ex_scim, key, value)
end
