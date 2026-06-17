defmodule ExScimPhoenix.Controller.GroupControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias ExScimPhoenix.Test.TestStorage

  @endpoint ExScimPhoenix.Test.Endpoint

  @group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"
  @list_schema "urn:ietf:params:scim:api:messages:2.0:ListResponse"
  @error_schema "urn:ietf:params:scim:api:messages:2.0:Error"
  @patch_schema "urn:ietf:params:scim:api:messages:2.0:PatchOp"

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

  describe "GET /Groups (index)" do
    test "returns a SCIM ListResponse" do
      create_group!("Engineering")
      create_group!("Sales")

      conn = get(auth_conn(), "/Groups")
      body = json_response(conn, 200)

      assert body["schemas"] == [@list_schema]
      assert body["totalResults"] == 2
      assert body["startIndex"] == 1
      assert length(body["Resources"]) == 2
    end

    test "empty list when no groups" do
      conn = get(auth_conn(), "/Groups")
      body = json_response(conn, 200)

      assert body["totalResults"] == 0
      assert body["Resources"] == []
    end

    test "applies filter query param" do
      create_group!("Engineering")
      create_group!("Sales")

      conn = get(auth_conn(), "/Groups", %{"filter" => ~s(displayName eq "Engineering")})
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert hd(body["Resources"])["displayName"] == "Engineering"
    end

    test "rejects invalid filter syntax with 400" do
      conn = get(auth_conn(), "/Groups", %{"filter" => "displayName eq"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end

    test "paginates with startIndex and count" do
      for n <- 1..5, do: create_group!("group#{n}")

      conn = get(auth_conn(), "/Groups", %{"startIndex" => "2", "count" => "2"})
      body = json_response(conn, 200)

      assert body["totalResults"] == 5
      assert body["startIndex"] == 2
      assert length(body["Resources"]) == 2
    end
  end

  describe "GET /Groups query param parsing" do
    test "accepts attributes and excludedAttributes params" do
      create_group!("Engineering")

      conn =
        get(auth_conn(), "/Groups", %{
          "attributes" => "displayName",
          "excludedAttributes" => "members"
        })

      assert json_response(conn, 200)["totalResults"] == 1
    end

    test "accepts sortBy and sortOrder=descending" do
      create_group!("Engineering")

      conn =
        get(auth_conn(), "/Groups", %{"sortBy" => "displayName", "sortOrder" => "descending"})

      assert json_response(conn, 200)["totalResults"] == 1
    end

    test "rejects invalid sortOrder with 400" do
      conn = get(auth_conn(), "/Groups", %{"sortOrder" => "sideways"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end

    test "clamps count above the maximum" do
      create_group!("Engineering")

      conn = get(auth_conn(), "/Groups", %{"count" => "5000"})
      assert json_response(conn, 200)["totalResults"] == 1
    end

    test "rejects non-integer count with 400" do
      conn = get(auth_conn(), "/Groups", %{"count" => "abc"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end

    test "rejects non-positive startIndex with 400" do
      conn = get(auth_conn(), "/Groups", %{"startIndex" => "0"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end
  end

  describe "POST /Groups (create)" do
    test "creates a group and returns 201" do
      conn = post(auth_conn(), "/Groups", scim_group("Engineering"))
      body = json_response(conn, 201)

      assert body["displayName"] == "Engineering"
      assert is_binary(body["id"])
      assert @group_schema in body["schemas"]
    end

    test "creates a group with members" do
      payload =
        scim_group("WithMembers")
        |> Map.put("members", [%{"value" => "user-1", "display" => "Alice"}])

      conn = post(auth_conn(), "/Groups", payload)
      body = json_response(conn, 201)

      assert length(body["members"]) == 1
      assert hd(body["members"])["value"] == "user-1"
    end

    test "rejects invalid payload (missing displayName) with 400" do
      conn = post(auth_conn(), "/Groups", %{"schemas" => [@group_schema]})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end

    test "rejects duplicate displayName with 409" do
      create_group!("Dupes")

      conn = post(auth_conn(), "/Groups", scim_group("Dupes"))
      assert json_response(conn, 409)["scimType"] == "uniqueness"
    end
  end

  describe "GET /Groups/:id (show)" do
    test "returns a single group" do
      created = create_group!("Engineering")

      conn = get(auth_conn(), "/Groups/#{created["id"]}")
      body = json_response(conn, 200)

      assert body["id"] == created["id"]
      assert body["displayName"] == "Engineering"
    end

    test "returns 404 for missing group" do
      conn = get(auth_conn(), "/Groups/nonexistent")
      body = json_response(conn, 404)

      assert body["schemas"] == [@error_schema]
      assert body["status"] == "404"
    end
  end

  describe "PUT /Groups/:id (update)" do
    test "replaces a group and returns 200" do
      created = create_group!("Engineering")

      replacement = %{
        "schemas" => [@group_schema],
        "displayName" => "Engineering Renamed",
        "members" => [%{"value" => "user-9", "display" => "Zara"}]
      }

      conn = put(auth_conn(), "/Groups/#{created["id"]}", replacement)
      body = json_response(conn, 200)

      assert body["id"] == created["id"]
      assert body["displayName"] == "Engineering Renamed"
      assert hd(body["members"])["value"] == "user-9"
    end

    test "returns 404 for missing group" do
      conn = put(auth_conn(), "/Groups/nonexistent", scim_group("Ghost"))
      assert json_response(conn, 404)["schemas"] == [@error_schema]
    end
  end

  describe "PATCH /Groups/:id (patch)" do
    test "applies patch operations and returns 200" do
      created = create_group!("Engineering")

      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "replace", "path" => "display_name", "value" => "Patched"}]
      }

      conn = patch(auth_conn(), "/Groups/#{created["id"]}", patch)
      assert json_response(conn, 200)["id"] == created["id"]
    end

    test "returns 404 for missing group" do
      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "replace", "path" => "display_name", "value" => "X"}]
      }

      conn = patch(auth_conn(), "/Groups/nonexistent", patch)
      assert json_response(conn, 404)["schemas"] == [@error_schema]
    end

    # SD-5: malformed patch op -> bare string error -> controller catch-all -> 500.
    test "malformed patch op currently returns 500 (SD-5, current behavior)" do
      created = create_group!("Engineering")

      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "frobnicate", "path" => "display_name", "value" => "X"}]
      }

      conn = patch(auth_conn(), "/Groups/#{created["id"]}", patch)
      assert json_response(conn, 500)["status"] == "500"
    end
  end

  describe "DELETE /Groups/:id (delete)" do
    test "deletes a group and returns 204" do
      created = create_group!("Engineering")

      conn = delete(auth_conn(), "/Groups/#{created["id"]}")
      assert conn.status == 204
      assert conn.resp_body == ""

      conn = get(auth_conn(), "/Groups/#{created["id"]}")
      assert json_response(conn, 404)
    end

    test "returns 404 for missing group" do
      conn = delete(auth_conn(), "/Groups/nonexistent")
      assert json_response(conn, 404)["schemas"] == [@error_schema]
    end
  end

  describe "authentication and authorization" do
    test "missing Authorization header returns 401" do
      conn = get(build_conn(), "/Groups")
      assert json_response(conn, 401)["schemas"] == [@error_schema]
    end

    test "invalid bearer token returns 401" do
      conn = get(auth_conn("bad-token"), "/Groups")
      assert json_response(conn, 401)["schemas"] == [@error_schema]
    end

    test "insufficient scope returns 403" do
      conn = post(auth_conn("token-readonly"), "/Groups", scim_group("Nope"))
      assert json_response(conn, 403)["scimType"] == "insufficientScope"
    end
  end

  # --- helpers ---

  defp auth_conn(token \\ "token-all") do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/scim+json")
    |> put_req_header("accept", "application/scim+json")
  end

  defp scim_group(display_name) do
    %{"schemas" => [@group_schema], "displayName" => display_name}
  end

  defp create_group!(display_name) do
    conn = post(auth_conn(), "/Groups", scim_group(display_name))
    json_response(conn, 201)
  end

  defp restore(key, nil), do: Application.delete_env(:ex_scim, key)
  defp restore(key, value), do: Application.put_env(:ex_scim, key, value)
end
