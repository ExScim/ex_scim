defmodule ExScimPhoenix.Plugs.AuthorizeTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  import ExScimPhoenix.Test.ConnHelpers

  alias ExScimPhoenix.Plugs.Authorize
  alias ExScim.Scope

  defmodule DenyAllPolicy do
    @behaviour ExScim.Authorization.Adapter

    @impl true
    def authorize(_scope, _resource, _action), do: {:error, :tenant_suspended}
  end

  setup do
    prev = Application.get_env(:ex_scim, :authorization_adapter)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:ex_scim, :authorization_adapter, prev),
        else: Application.delete_env(:ex_scim, :authorization_adapter)
    end)

    :ok
  end

  defp run(scope, opts) do
    conn = conn(:get, "/Users")
    conn = if scope, do: assign(conn, :scim_scope, scope), else: conn
    Authorize.call(conn, Authorize.init(opts))
  end

  describe "init/1" do
    test "requires resource and action" do
      assert %{resource: :users, action: :read} = Authorize.init(resource: :users, action: :read)
      assert_raise KeyError, fn -> Authorize.init(resource: :users) end
    end
  end

  describe "call/2" do
    test "passes through when the policy allows" do
      conn = run(%Scope{id: "c", scopes: ["scim:read"]}, resource: :users, action: :read)
      refute conn.halted
    end

    test "halts with 403 and names missing scopes when the policy denies" do
      conn = run(%Scope{id: "c", scopes: ["scim:read"]}, resource: :users, action: :delete)

      assert conn.halted
      assert conn.status == 403

      resp = decode_response(conn)
      assert resp["scimType"] == "insufficientScope"
      assert resp["detail"] == "Missing required scope(s): scim:delete"
    end

    test "uses a generic detail for custom denial reasons" do
      Application.put_env(:ex_scim, :authorization_adapter, DenyAllPolicy)

      conn = run(%Scope{id: "c", scopes: ["scim:read"]}, resource: :users, action: :read)

      assert conn.status == 403

      assert decode_response(conn)["detail"] ==
               "Operation is not permitted based on the supplied authorization"
    end

    test "halts with 401 when no scope is assigned" do
      conn = run(nil, resource: :users, action: :read)

      assert conn.halted
      assert conn.status == 401
      assert decode_response(conn)["scimType"] == "noAuthn"
    end
  end
end
