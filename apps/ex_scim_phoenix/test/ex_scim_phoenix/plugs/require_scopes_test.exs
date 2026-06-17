defmodule ExScimPhoenix.Plugs.RequireScopesTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn
  import ExScimPhoenix.Test.ConnHelpers

  alias ExScimPhoenix.Plugs.RequireScopes
  alias ExScim.Scope

  describe "init/1" do
    test "wraps scopes into a map" do
      assert %{scopes: ["scim:read"]} = RequireScopes.init(scopes: ["scim:read"])
    end

    test "wraps a single scope string into a list" do
      assert %{scopes: ["scim:read"]} = RequireScopes.init(scopes: "scim:read")
    end

    test "defaults to empty scopes" do
      assert %{scopes: []} = RequireScopes.init([])
    end
  end

  describe "call/2 with required scopes present" do
    test "passes through when scope is present" do
      scope = %Scope{id: "user-1", scopes: ["scim:read", "scim:create"]}
      opts = RequireScopes.init(scopes: ["scim:read"])

      conn =
        conn(:get, "/Users")
        |> assign(:scim_scope, scope)
        |> RequireScopes.call(opts)

      refute conn.halted
    end

    test "passes through when multiple required scopes are all present" do
      scope = %Scope{id: "user-1", scopes: ["scim:read", "scim:create", "scim:delete"]}
      opts = RequireScopes.init(scopes: ["scim:read", "scim:create"])

      conn =
        conn(:get, "/Users")
        |> assign(:scim_scope, scope)
        |> RequireScopes.call(opts)

      refute conn.halted
    end

    test "passes through when no scopes are required" do
      scope = %Scope{id: "user-1", scopes: []}
      opts = RequireScopes.init(scopes: [])

      conn =
        conn(:get, "/Users")
        |> assign(:scim_scope, scope)
        |> RequireScopes.call(opts)

      refute conn.halted
    end
  end

  describe "call/2 with missing scopes" do
    test "halts with 403 when required scope is missing" do
      scope = %Scope{id: "user-1", scopes: ["scim:read"]}
      opts = RequireScopes.init(scopes: ["scim:create"])

      conn =
        conn(:get, "/Users")
        |> assign(:scim_scope, scope)
        |> RequireScopes.call(opts)

      assert conn.halted
      assert conn.status == 403

      resp = decode_response(conn)
      assert resp["scimType"] == "insufficientScope"
      assert resp["detail"] =~ "scim:create"
    end

    test "halts when one of multiple required scopes is missing" do
      scope = %Scope{id: "user-1", scopes: ["scim:read"]}
      opts = RequireScopes.init(scopes: ["scim:read", "scim:delete"])

      conn =
        conn(:get, "/Users")
        |> assign(:scim_scope, scope)
        |> RequireScopes.call(opts)

      assert conn.halted
      assert conn.status == 403
    end

    test "halts when scope list is empty but scopes are required" do
      scope = %Scope{id: "user-1", scopes: []}
      opts = RequireScopes.init(scopes: ["scim:read"])

      conn =
        conn(:get, "/Users")
        |> assign(:scim_scope, scope)
        |> RequireScopes.call(opts)

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "call/2 without scim_scope assigned" do
    test "halts with 401 when scim_scope is missing from assigns" do
      opts = RequireScopes.init(scopes: ["scim:read"])

      conn =
        conn(:get, "/Users")
        |> RequireScopes.call(opts)

      assert conn.halted
      assert conn.status == 401

      resp = decode_response(conn)
      assert resp["scimType"] == "noAuthn"
    end
  end
end
