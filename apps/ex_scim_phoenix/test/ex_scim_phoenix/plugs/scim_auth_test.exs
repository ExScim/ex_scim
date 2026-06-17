defmodule ExScimPhoenix.Plugs.ScimAuthTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  import ExScimPhoenix.Test.ConnHelpers

  alias ExScimPhoenix.Plugs.ScimAuth
  alias ExScim.Scope

  defmodule AcceptingAuth do
    @behaviour ExScim.Auth.AuthProvider.Adapter

    @impl true
    def validate_bearer("valid-token") do
      {:ok, %Scope{id: "user-1", scopes: ["scim:read"]}}
    end

    def validate_bearer(_), do: {:error, :token_not_found}

    @impl true
    def validate_basic("admin", "secret") do
      {:ok, %Scope{id: "admin-1", scopes: ["scim:read", "scim:create"]}}
    end

    def validate_basic(_, _), do: {:error, :invalid_credentials}
  end

  setup do
    original = Application.get_env(:ex_scim, :auth_provider_adapter)
    Application.put_env(:ex_scim, :auth_provider_adapter, AcceptingAuth)

    on_exit(fn ->
      if original do
        Application.put_env(:ex_scim, :auth_provider_adapter, original)
      else
        Application.delete_env(:ex_scim, :auth_provider_adapter)
      end
    end)

    :ok
  end

  describe "Bearer auth" do
    test "valid token sets scim_scope" do
      conn =
        conn(:get, "/Users")
        |> put_req_header("authorization", "Bearer valid-token")
        |> ScimAuth.call(ScimAuth.init([]))

      refute conn.halted
      assert %Scope{id: "user-1"} = conn.assigns.scim_scope
    end

    test "invalid token halts with 401" do
      conn =
        conn(:get, "/Users")
        |> put_req_header("authorization", "Bearer bad-token")
        |> ScimAuth.call(ScimAuth.init([]))

      assert conn.halted
      assert conn.status == 401

      resp = decode_response(conn)
      assert resp["status"] == "401"
      assert resp["scimType"] == "invalidCredentials"
    end

    test "sets WWW-Authenticate header on failure" do
      conn =
        conn(:get, "/Users")
        |> put_req_header("authorization", "Bearer bad-token")
        |> ScimAuth.call(ScimAuth.init([]))

      assert get_resp_header(conn, "www-authenticate") == ["Bearer, Basic"]
    end
  end

  describe "Basic auth" do
    test "valid credentials set scim_scope" do
      encoded = Base.encode64("admin:secret")

      conn =
        conn(:get, "/Users")
        |> put_req_header("authorization", "Basic #{encoded}")
        |> ScimAuth.call(ScimAuth.init([]))

      refute conn.halted
      assert %Scope{id: "admin-1"} = conn.assigns.scim_scope
    end

    test "invalid credentials halt with 401" do
      encoded = Base.encode64("admin:wrong")

      conn =
        conn(:get, "/Users")
        |> put_req_header("authorization", "Basic #{encoded}")
        |> ScimAuth.call(ScimAuth.init([]))

      assert conn.halted
      assert conn.status == 401
    end

    test "malformed base64 halts with 401" do
      conn =
        conn(:get, "/Users")
        |> put_req_header("authorization", "Basic !!!not-base64!!!")
        |> ScimAuth.call(ScimAuth.init([]))

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "missing or unsupported auth" do
    test "missing Authorization header halts with 401" do
      conn =
        conn(:get, "/Users")
        |> ScimAuth.call(ScimAuth.init([]))

      assert conn.halted
      assert conn.status == 401

      resp = decode_response(conn)
      assert resp["detail"] == "Authentication required"
    end

    test "unsupported scheme halts with 401" do
      conn =
        conn(:get, "/Users")
        |> put_req_header("authorization", "Digest abc123")
        |> ScimAuth.call(ScimAuth.init([]))

      assert conn.halted
      assert conn.status == 401

      resp = decode_response(conn)
      assert resp["detail"] == "Unsupported authentication method"
    end
  end

  describe "init/1" do
    test "returns opts unchanged" do
      assert ScimAuth.init([]) == []
      assert ScimAuth.init(foo: :bar) == [foo: :bar]
    end
  end
end
