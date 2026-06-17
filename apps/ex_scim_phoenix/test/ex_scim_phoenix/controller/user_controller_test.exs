defmodule ExScimPhoenix.Controller.UserControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias ExScimPhoenix.Test.TestStorage

  @endpoint ExScimPhoenix.Test.Endpoint

  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"
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

  describe "GET /Users (index)" do
    test "returns a SCIM ListResponse" do
      create_user!("alice")
      create_user!("bob")

      conn = get(auth_conn(), "/Users")
      body = json_response(conn, 200)

      assert body["schemas"] == [@list_schema]
      assert body["totalResults"] == 2
      assert body["startIndex"] == 1
      assert body["itemsPerPage"] == 2
      assert length(body["Resources"]) == 2
    end

    test "empty list when no users" do
      conn = get(auth_conn(), "/Users")
      body = json_response(conn, 200)

      assert body["totalResults"] == 0
      assert body["Resources"] == []
    end

    test "applies filter query param" do
      create_user!("alice")
      create_user!("bob")

      conn = get(auth_conn(), "/Users", %{"filter" => ~s(userName eq "alice")})
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert hd(body["Resources"])["userName"] == "alice"
    end

    test "rejects invalid filter syntax with 400" do
      conn = get(auth_conn(), "/Users", %{"filter" => "userName eq"})
      body = json_response(conn, 400)

      assert body["schemas"] == [@error_schema]
      assert body["scimType"] == "invalidFilter"
    end

    test "paginates with startIndex and count" do
      for n <- 1..5, do: create_user!("user#{n}")

      conn = get(auth_conn(), "/Users", %{"startIndex" => "2", "count" => "2"})
      body = json_response(conn, 200)

      assert body["totalResults"] == 5
      assert body["startIndex"] == 2
      assert length(body["Resources"]) == 2
    end
  end

  describe "GET /Users query param parsing" do
    test "accepts attributes and excludedAttributes params" do
      create_user!("alice")

      conn =
        get(auth_conn(), "/Users", %{
          "attributes" => "userName, name",
          "excludedAttributes" => "emails"
        })

      assert json_response(conn, 200)["totalResults"] == 1
    end

    test "accepts sortBy and sortOrder=descending" do
      create_user!("alice")

      conn = get(auth_conn(), "/Users", %{"sortBy" => "userName", "sortOrder" => "descending"})
      assert json_response(conn, 200)["totalResults"] == 1
    end

    test "rejects invalid sortOrder with 400" do
      conn = get(auth_conn(), "/Users", %{"sortOrder" => "sideways"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end

    test "clamps count above the maximum (200)" do
      create_user!("alice")

      conn = get(auth_conn(), "/Users", %{"count" => "5000"})
      body = json_response(conn, 200)

      # request still succeeds; count is clamped server-side to @max_count
      assert body["totalResults"] == 1
    end

    # Note: a negative count arrives as a string and fails parse_integer_param's
    # `> 0` guard, so it returns 400. The validate_count(count < 0) -> 0 branch is
    # unreachable via HTTP query strings (only via a literal negative integer).
    test "rejects negative count with 400" do
      conn = get(auth_conn(), "/Users", %{"count" => "-3"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end

    test "rejects non-integer count with 400" do
      conn = get(auth_conn(), "/Users", %{"count" => "abc"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end

    test "rejects non-positive startIndex with 400" do
      conn = get(auth_conn(), "/Users", %{"startIndex" => "0"})
      assert json_response(conn, 400)["schemas"] == [@error_schema]
    end
  end

  describe "POST /Users (create)" do
    test "creates a user and returns 201" do
      conn = post(auth_conn(), "/Users", scim_user("john.doe"))
      body = json_response(conn, 201)

      assert body["userName"] == "john.doe"
      assert is_binary(body["id"])
      assert @user_schema in body["schemas"]
    end

    # SD-4: the Operations layer calls to_scim/2 without a :location opt, so
    # meta.location is nil and the controller emits no Location header, despite
    # RFC 7644 §3.3 (SHOULD). Documented as current behavior pending a fix.
    test "does NOT set a Location header (SD-4, current behavior)" do
      conn = post(auth_conn(), "/Users", scim_user("john.doe"))
      assert json_response(conn, 201)
      assert get_resp_header(conn, "location") == []
    end

    test "rejects invalid payload (missing userName) with 400" do
      payload = %{"schemas" => [@user_schema], "name" => %{"givenName" => "No"}}

      conn = post(auth_conn(), "/Users", payload)
      body = json_response(conn, 400)

      assert body["schemas"] == [@error_schema]
    end

    test "rejects duplicate userName with 409" do
      create_user!("dupe")

      conn = post(auth_conn(), "/Users", scim_user("dupe"))
      body = json_response(conn, 409)

      assert body["scimType"] == "uniqueness"
    end
  end

  describe "GET /Users/:id (show)" do
    test "returns a single user" do
      created = create_user!("alice")

      conn = get(auth_conn(), "/Users/#{created["id"]}")
      body = json_response(conn, 200)

      assert body["id"] == created["id"]
      assert body["userName"] == "alice"
    end

    test "returns 404 for missing user" do
      conn = get(auth_conn(), "/Users/nonexistent")
      body = json_response(conn, 404)

      assert body["schemas"] == [@error_schema]
      assert body["status"] == "404"
    end
  end

  describe "PUT /Users/:id (update)" do
    test "replaces a user and returns 200" do
      created = create_user!("alice")

      replacement = %{
        "schemas" => [@user_schema],
        "userName" => "alice.renamed",
        "name" => %{"givenName" => "Alice", "familyName" => "Renamed"}
      }

      conn = put(auth_conn(), "/Users/#{created["id"]}", replacement)
      body = json_response(conn, 200)

      assert body["id"] == created["id"]
      assert body["userName"] == "alice.renamed"
    end

    test "returns 404 for missing user" do
      conn = put(auth_conn(), "/Users/nonexistent", scim_user("ghost"))
      body = json_response(conn, 404)

      assert body["schemas"] == [@error_schema]
    end
  end

  describe "PATCH /Users/:id (patch)" do
    test "applies patch operations and returns 200" do
      created = create_user!("alice")

      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "replace", "path" => "display_name", "value" => "Patched"}]
      }

      conn = patch(auth_conn(), "/Users/#{created["id"]}", patch)
      body = json_response(conn, 200)

      assert body["id"] == created["id"]
    end

    test "returns 404 for missing user" do
      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "replace", "path" => "display_name", "value" => "X"}]
      }

      conn = patch(auth_conn(), "/Users/nonexistent", patch)
      assert json_response(conn, 404)["schemas"] == [@error_schema]
    end

    # SD-5: the Patcher returns a bare string error (e.g. "Unsupported op: ...")
    # for malformed ops. The controller has clauses for :invalid_patch_operation
    # / :no_target / :invalid_path atoms (which the Patcher never emits) plus a
    # list-of-errors clause; a string falls through to the catch-all -> 500.
    # Ideally a malformed patch op would be a 400 invalidSyntax.
    test "malformed patch op currently returns 500 (SD-5, current behavior)" do
      created = create_user!("alice")

      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "frobnicate", "path" => "display_name", "value" => "X"}]
      }

      conn = patch(auth_conn(), "/Users/#{created["id"]}", patch)
      body = json_response(conn, 500)

      assert body["schemas"] == [@error_schema]
      assert body["status"] == "500"
    end
  end

  describe "DELETE /Users/:id (delete)" do
    test "deletes a user and returns 204" do
      created = create_user!("alice")

      conn = delete(auth_conn(), "/Users/#{created["id"]}")
      assert conn.status == 204
      assert conn.resp_body == ""

      # confirm gone
      conn = get(auth_conn(), "/Users/#{created["id"]}")
      assert json_response(conn, 404)
    end

    test "returns 404 for missing user" do
      conn = delete(auth_conn(), "/Users/nonexistent")
      assert json_response(conn, 404)["schemas"] == [@error_schema]
    end
  end

  describe "authentication and authorization" do
    test "missing Authorization header returns 401" do
      conn = get(build_conn(), "/Users")
      body = json_response(conn, 401)

      assert body["schemas"] == [@error_schema]
      assert [_] = get_resp_header(conn, "www-authenticate")
    end

    test "invalid bearer token returns 401" do
      conn = get(auth_conn("bad-token"), "/Users")
      assert json_response(conn, 401)["schemas"] == [@error_schema]
    end

    test "insufficient scope returns 403" do
      conn = post(auth_conn("token-readonly"), "/Users", scim_user("nope"))
      body = json_response(conn, 403)

      assert body["scimType"] == "insufficientScope"
    end

    test "read-only token can still GET" do
      create_user!("alice")
      conn = get(auth_conn("token-readonly"), "/Users")
      assert json_response(conn, 200)["totalResults"] == 1
    end
  end

  # --- helpers ---

  defp auth_conn(token \\ "token-all") do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/scim+json")
    |> put_req_header("accept", "application/scim+json")
  end

  defp scim_user(user_name) do
    %{
      "schemas" => [@user_schema],
      "userName" => user_name,
      "name" => %{"givenName" => "Test", "familyName" => "User"},
      "active" => true
    }
  end

  defp create_user!(user_name) do
    conn = post(auth_conn(), "/Users", scim_user(user_name))
    json_response(conn, 201)
  end

  defp restore(key, nil), do: Application.delete_env(:ex_scim, key)
  defp restore(key, value), do: Application.put_env(:ex_scim, key, value)
end
