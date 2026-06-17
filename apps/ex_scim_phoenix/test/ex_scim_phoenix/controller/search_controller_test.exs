defmodule ExScimPhoenix.Controller.SearchControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias ExScimPhoenix.Test.TestStorage

  @endpoint ExScimPhoenix.Test.Endpoint

  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"
  @group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"
  @list_schema "urn:ietf:params:scim:api:messages:2.0:ListResponse"
  @search_schema "urn:ietf:params:scim:api:messages:2.0:SearchRequest"

  setup do
    {:ok, _} = TestStorage.start_link()
    prev_storage = Application.get_env(:ex_scim, :storage_strategy)
    prev_auth = Application.get_env(:ex_scim, :auth_provider_adapter)
    prev_lifecycle = Application.get_env(:ex_scim, :lifecycle_adapter)

    Application.put_env(:ex_scim, :storage_strategy, TestStorage)
    Application.put_env(:ex_scim, :auth_provider_adapter, ExScimPhoenix.Test.TestAuth)
    Application.delete_env(:ex_scim, :lifecycle_adapter)

    on_exit(fn ->
      restore(:storage_strategy, prev_storage)
      restore(:auth_provider_adapter, prev_auth)
      restore(:lifecycle_adapter, prev_lifecycle)
      TestStorage.stop()
    end)

    :ok
  end

  describe "POST /Users/.search" do
    test "returns a ListResponse of users" do
      create_user!("alice")
      create_user!("bob")

      conn = post(auth_conn(), "/Users/.search", search_request())
      body = json_response(conn, 200)

      assert body["schemas"] == [@list_schema]
      assert body["totalResults"] == 2
      assert length(body["Resources"]) == 2
    end

    test "applies a filter from the request body" do
      create_user!("alice")
      create_user!("bob")

      conn =
        post(
          auth_conn(),
          "/Users/.search",
          search_request(%{"filter" => ~s(userName eq "alice")})
        )

      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert hd(body["Resources"])["userName"] == "alice"
    end

    test "applies pagination from the request body" do
      for n <- 1..5, do: create_user!("user#{n}")

      conn =
        post(auth_conn(), "/Users/.search", search_request(%{"startIndex" => 2, "count" => 2}))

      body = json_response(conn, 200)

      assert body["totalResults"] == 5
      assert body["startIndex"] == 2
      assert length(body["Resources"]) == 2
    end

    # SD-6: parse_search_filter_param interpolates the NimbleParsec position
    # tuple (line = {1, 0}) into a string, which raises Protocol.UndefinedError
    # (String.Chars not implemented for Tuple). So an invalid filter crashes
    # (500) instead of returning a clean 400 invalidValue. UserController avoids
    # this by not interpolating line/column. Asserting the raise documents the
    # current behavior; the fix is to drop the line/column interpolation.
    test "invalid filter currently crashes (SD-6, current behavior)" do
      assert_raise Protocol.UndefinedError, fn ->
        post(auth_conn(), "/Users/.search", search_request(%{"filter" => "userName eq"}))
      end
    end

    test "rejects an empty request body with 400" do
      conn = post(auth_conn(), "/Users/.search", %{})
      assert json_response(conn, 400)["scimType"] == "invalidSyntax"
    end
  end

  describe "POST /Groups/.search" do
    test "returns a ListResponse of groups" do
      create_group!("Engineering")

      conn = post(auth_conn(), "/Groups/.search", search_request())
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert hd(body["Resources"])["displayName"] == "Engineering"
    end
  end

  describe "POST /.search (cross-resource)" do
    test "returns combined users and groups with resourceType meta" do
      create_user!("alice")
      create_group!("Engineering")

      conn = post(auth_conn(), "/.search", search_request())
      body = json_response(conn, 200)

      assert body["totalResults"] == 2
      resource_types = Enum.map(body["Resources"], &get_in(&1, ["meta", "resourceType"]))
      assert "User" in resource_types
      assert "Group" in resource_types
    end
  end

  # --- helpers ---

  defp search_request(extra \\ %{}) do
    Map.merge(%{"schemas" => [@search_schema]}, extra)
  end

  defp auth_conn(token \\ "token-all") do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/scim+json")
    |> put_req_header("accept", "application/scim+json")
  end

  defp create_user!(user_name) do
    payload = %{
      "schemas" => [@user_schema],
      "userName" => user_name,
      "name" => %{"givenName" => "Test", "familyName" => "User"}
    }

    conn = post(auth_conn(), "/Users", payload)
    json_response(conn, 201)
  end

  defp create_group!(display_name) do
    payload = %{"schemas" => [@group_schema], "displayName" => display_name}
    conn = post(auth_conn(), "/Groups", payload)
    json_response(conn, 201)
  end

  defp restore(key, nil), do: Application.delete_env(:ex_scim, key)
  defp restore(key, value), do: Application.put_env(:ex_scim, key, value)
end
