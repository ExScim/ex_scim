defmodule ExScimPhoenix.Plugs.ScimTenantTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  alias ExScimPhoenix.Plugs.ScimTenant
  alias ExScim.Scope

  setup do
    original = Application.get_env(:ex_scim, :tenant_resolver)

    on_exit(fn ->
      if original do
        Application.put_env(:ex_scim, :tenant_resolver, original)
      else
        Application.delete_env(:ex_scim, :tenant_resolver)
      end
    end)

    :ok
  end

  describe "no resolver configured" do
    setup do
      Application.delete_env(:ex_scim, :tenant_resolver)
      :ok
    end

    test "passes through as no-op" do
      scope = %Scope{id: "user_1", scopes: ["scim:read"]}

      conn =
        conn(:get, "/scim/v2/Users")
        |> assign(:scim_scope, scope)
        |> ScimTenant.call(ScimTenant.init([]))

      assert conn.assigns.scim_scope == scope
      assert conn.assigns.scim_scope.tenant_id == nil
      refute conn.halted
    end
  end

  describe "with resolver configured" do
    test "sets tenant_id on scope when resolver succeeds" do
      defmodule SuccessResolver do
        @behaviour ExScim.Tenant.Resolver

        @impl true
        def resolve_tenant(_conn, _scope), do: {:ok, "tenant_abc"}
      end

      Application.put_env(:ex_scim, :tenant_resolver, SuccessResolver)

      scope = %Scope{id: "user_1", scopes: ["scim:read"]}

      conn =
        conn(:get, "/scim/v2/Users")
        |> assign(:scim_scope, scope)
        |> ScimTenant.call(ScimTenant.init([]))

      assert conn.assigns.scim_scope.tenant_id == "tenant_abc"
      assert conn.assigns.scim_scope.id == "user_1"
      assert conn.assigns.scim_scope.scopes == ["scim:read"]
      refute conn.halted
    end

    test "preserves all scope fields when setting tenant_id" do
      defmodule PreserveResolver do
        @behaviour ExScim.Tenant.Resolver

        @impl true
        def resolve_tenant(_conn, _scope), do: {:ok, "tenant_xyz"}
      end

      Application.put_env(:ex_scim, :tenant_resolver, PreserveResolver)

      scope = %Scope{
        id: "user_1",
        scopes: ["scim:read", "scim:write"],
        username: "admin",
        display_name: "Admin",
        metadata: %{"key" => "value"}
      }

      conn =
        conn(:get, "/scim/v2/Users")
        |> assign(:scim_scope, scope)
        |> ScimTenant.call(ScimTenant.init([]))

      updated_scope = conn.assigns.scim_scope
      assert updated_scope.tenant_id == "tenant_xyz"
      assert updated_scope.id == "user_1"
      assert updated_scope.scopes == ["scim:read", "scim:write"]
      assert updated_scope.username == "admin"
      assert updated_scope.display_name == "Admin"
      assert updated_scope.metadata == %{"key" => "value"}
    end

    test "resolver receives the conn and scope" do
      defmodule ConnCapturingResolver do
        @behaviour ExScim.Tenant.Resolver

        @impl true
        def resolve_tenant(conn, scope) do
          # Verify the resolver gets the right arguments
          Process.put(:captured_conn_path, conn.request_path)
          Process.put(:captured_scope_id, scope.id)
          {:ok, "tenant_1"}
        end
      end

      Application.put_env(:ex_scim, :tenant_resolver, ConnCapturingResolver)

      scope = %Scope{id: "user_1", scopes: ["scim:read"]}

      conn(:get, "/scim/v2/Users")
      |> assign(:scim_scope, scope)
      |> ScimTenant.call(ScimTenant.init([]))

      assert Process.get(:captured_conn_path) == "/scim/v2/Users"
      assert Process.get(:captured_scope_id) == "user_1"
    end
  end

  describe "init/1" do
    test "returns opts unchanged" do
      assert ScimTenant.init([]) == []
      assert ScimTenant.init(foo: :bar) == [foo: :bar]
    end
  end
end
