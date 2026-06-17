defmodule ExScimPhoenix.Controller.SchemaControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint ExScimPhoenix.Test.Endpoint

  @list_schema "urn:ietf:params:scim:api:messages:2.0:ListResponse"
  @error_schema "urn:ietf:params:scim:api:messages:2.0:Error"
  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"

  setup do
    prev_auth = Application.get_env(:ex_scim, :auth_provider_adapter)
    Application.put_env(:ex_scim, :auth_provider_adapter, ExScimPhoenix.Test.TestAuth)

    on_exit(fn ->
      if prev_auth do
        Application.put_env(:ex_scim, :auth_provider_adapter, prev_auth)
      else
        Application.delete_env(:ex_scim, :auth_provider_adapter)
      end
    end)

    :ok
  end

  describe "GET /Schemas (index)" do
    test "returns all schemas as a ListResponse" do
      conn = get(auth_conn(), "/Schemas")
      body = json_response(conn, 200)

      assert body["schemas"] == [@list_schema]
      assert body["totalResults"] == length(body["Resources"])
      assert body["totalResults"] > 0
      assert is_list(body["Resources"])
    end

    test "includes the core User schema" do
      conn = get(auth_conn(), "/Schemas")
      body = json_response(conn, 200)

      ids = Enum.map(body["Resources"], & &1["id"])
      assert @user_schema in ids
    end

    test "requires authentication" do
      conn = get(build_conn(), "/Schemas")
      assert json_response(conn, 401)["schemas"] == [@error_schema]
    end
  end

  describe "GET /Schemas/:id (show)" do
    test "returns a specific schema by URN" do
      conn = get(auth_conn(), "/Schemas/#{@user_schema}")
      body = json_response(conn, 200)

      assert body["id"] == @user_schema
    end

    test "returns 404 for an unknown schema" do
      conn = get(auth_conn(), "/Schemas/urn:example:unknown")
      body = json_response(conn, 404)

      assert body["schemas"] == [@error_schema]
      assert body["status"] == "404"
      assert body["detail"] =~ "not found"
    end
  end

  defp auth_conn(token \\ "token-readonly") do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("accept", "application/scim+json")
  end
end
