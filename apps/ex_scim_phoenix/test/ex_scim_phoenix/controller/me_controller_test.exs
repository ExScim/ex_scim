defmodule ExScimPhoenix.Controller.MeControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias ExScimPhoenix.Test.TestStorage

  @endpoint ExScimPhoenix.Test.Endpoint

  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"
  @error_schema "urn:ietf:params:scim:api:messages:2.0:Error"
  @patch_schema "urn:ietf:params:scim:api:messages:2.0:PatchOp"

  # token-me authenticates as scope.id == "me-user"
  @me_id "me-user"

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

  describe "GET /Me (show)" do
    test "returns the authenticated user with a Location header" do
      seed_me_user!()

      conn = get(me_conn(), "/Me")
      body = json_response(conn, 200)

      assert body["id"] == @me_id
      assert body["userName"] == "me.user"
      assert [location] = get_resp_header(conn, "location")
      assert location == body["meta"]["location"]
      assert location =~ "/Users/#{@me_id}"
    end

    test "returns 404 when the authenticated user does not exist" do
      conn = get(me_conn(), "/Me")
      body = json_response(conn, 404)

      assert body["schemas"] == [@error_schema]
      assert body["detail"] =~ "Authenticated user not found"
    end

    test "requires the scim:me:read scope (403 with a plain read token)" do
      seed_me_user!()

      conn = get(authed("token-readonly"), "/Me")
      assert json_response(conn, 403)["scimType"] == "insufficientScope"
    end
  end

  describe "POST /Me (create)" do
    test "self-registers a user and returns 201 with a Location header" do
      payload = %{
        "schemas" => [@user_schema],
        "userName" => "self.registered",
        "name" => %{"givenName" => "Self", "familyName" => "Registered"}
      }

      conn = post(me_conn(), "/Me", payload)
      body = json_response(conn, 201)

      assert body["userName"] == "self.registered"
      assert body["externalId"] == @me_id
      assert [location] = get_resp_header(conn, "location")
      assert location == body["meta"]["location"]
      assert location =~ "/Users/#{body["id"]}"
    end

    test "enriches self-registration from JWT claims" do
      conn = post(authed("token-me-claims"), "/Me", %{"schemas" => [@user_schema]})
      body = json_response(conn, 201)

      assert body["userName"] == "claims.user"
      assert body["externalId"] == "sub-123"
      assert body["name"] == %{"givenName" => "Claims", "familyName" => "User"}
      assert body["emails"] == [%{"value" => "claims@test.com", "primary" => true}]
    end

    test "enriches self-registration from OAuth user_info" do
      conn = post(authed("token-me-userinfo"), "/Me", %{"schemas" => [@user_schema]})
      body = json_response(conn, 201)

      assert body["userName"] == "userinfo.user"
      assert body["externalId"] == "subj-456"
      assert is_list(body["emails"])
      assert hd(body["emails"])["value"] == "userinfo@test.com"
    end
  end

  describe "PUT /Me (update)" do
    test "replaces the authenticated user and returns 200" do
      seed_me_user!()

      replacement = %{
        "schemas" => [@user_schema],
        "userName" => "me.renamed",
        "name" => %{"givenName" => "Me", "familyName" => "Renamed"}
      }

      conn = put(me_conn(), "/Me", replacement)
      body = json_response(conn, 200)

      assert body["id"] == @me_id
      assert body["userName"] == "me.renamed"
      assert [_] = get_resp_header(conn, "location")
    end
  end

  describe "PATCH /Me (patch)" do
    test "patches the authenticated user and returns 200" do
      seed_me_user!()

      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "replace", "path" => "display_name", "value" => "Patched"}]
      }

      conn = patch(me_conn(), "/Me", patch)
      assert json_response(conn, 200)["id"] == @me_id
    end

    test "rejects an unsupported op with 400 invalidSyntax" do
      seed_me_user!()

      patch = %{
        "schemas" => [@patch_schema],
        "Operations" => [%{"op" => "frobnicate", "path" => "display_name", "value" => "X"}]
      }

      conn = patch(me_conn(), "/Me", patch)
      assert json_response(conn, 400)["scimType"] == "invalidSyntax"
    end
  end

  describe "DELETE /Me (delete)" do
    test "deletes the authenticated user and returns 204" do
      seed_me_user!()

      conn = delete(me_conn(), "/Me")
      assert conn.status == 204

      # confirm gone
      conn = get(me_conn(), "/Me")
      assert json_response(conn, 404)
    end

    test "returns 404 when the authenticated user does not exist" do
      conn = delete(me_conn(), "/Me")
      assert json_response(conn, 404)["schemas"] == [@error_schema]
    end
  end

  # --- helpers ---

  defp me_conn, do: authed("token-me")

  defp authed(token) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/scim+json")
    |> put_req_header("accept", "application/scim+json")
  end

  # Seed a user whose id matches token-me's scope id, via POST /Users with token-all.
  defp seed_me_user! do
    payload = %{
      "id" => @me_id,
      "schemas" => [@user_schema],
      "userName" => "me.user",
      "name" => %{"givenName" => "Me", "familyName" => "User"},
      "active" => true
    }

    conn = post(authed("token-all"), "/Users", payload)
    json_response(conn, 201)
  end

  defp restore(key, nil), do: Application.delete_env(:ex_scim, key)
  defp restore(key, value), do: Application.put_env(:ex_scim, key, value)
end
