defmodule ExScim.ConfigTest do
  use ExUnit.Case

  alias ExScim.Config
  alias ExScim.Scope

  setup do
    original_base_url = Application.get_env(:ex_scim, :base_url)
    original_resolver = Application.get_env(:ex_scim, :tenant_resolver)

    on_exit(fn ->
      if original_base_url do
        Application.put_env(:ex_scim, :base_url, original_base_url)
      else
        Application.delete_env(:ex_scim, :base_url)
      end

      if original_resolver do
        Application.put_env(:ex_scim, :tenant_resolver, original_resolver)
      else
        Application.delete_env(:ex_scim, :tenant_resolver)
      end
    end)

    Application.put_env(:ex_scim, :base_url, "https://example.com")
    :ok
  end

  describe "resource_url/2 (without scope)" do
    test "generates URL with global base" do
      assert Config.resource_url("Users", "123") == "https://example.com/scim/v2/Users/123"
    end

    test "generates URL for groups" do
      assert Config.resource_url("Groups", "456") == "https://example.com/scim/v2/Groups/456"
    end
  end

  describe "resource_url/3 (with scope)" do
    test "falls back to global URL when scope is nil" do
      assert Config.resource_url("Users", "123", nil) ==
               "https://example.com/scim/v2/Users/123"
    end

    test "falls back to global URL when tenant_id is nil" do
      scope = %Scope{id: "user_1", scopes: [], tenant_id: nil}

      assert Config.resource_url("Users", "123", scope) ==
               "https://example.com/scim/v2/Users/123"
    end

    test "falls back to global URL when no tenant resolver configured" do
      Application.delete_env(:ex_scim, :tenant_resolver)
      scope = %Scope{id: "user_1", scopes: [], tenant_id: "org_1"}

      assert Config.resource_url("Users", "123", scope) ==
               "https://example.com/scim/v2/Users/123"
    end

    test "uses tenant base URL when resolver implements tenant_scim_base_url/1" do
      defmodule TenantAwareResolver do
        @behaviour ExScim.Tenant.Resolver

        @impl true
        def resolve_tenant(_conn, _scope), do: {:ok, "org_1"}

        @impl true
        def tenant_scim_base_url(tenant_id), do: "https://#{tenant_id}.example.com/scim/v2"
      end

      Application.put_env(:ex_scim, :tenant_resolver, TenantAwareResolver)
      scope = %Scope{id: "user_1", scopes: [], tenant_id: "org_1"}

      assert Config.resource_url("Users", "123", scope) ==
               "https://org_1.example.com/scim/v2/Users/123"
    end

    test "falls back to global URL when resolver does not implement tenant_scim_base_url/1" do
      defmodule SimpleResolver do
        @behaviour ExScim.Tenant.Resolver

        @impl true
        def resolve_tenant(_conn, _scope), do: {:ok, "org_1"}
      end

      Application.put_env(:ex_scim, :tenant_resolver, SimpleResolver)
      scope = %Scope{id: "user_1", scopes: [], tenant_id: "org_1"}

      assert Config.resource_url("Users", "123", scope) ==
               "https://example.com/scim/v2/Users/123"
    end
  end

  describe "collection_url/1 (without scope)" do
    test "generates collection URL" do
      assert Config.collection_url("Users") == "https://example.com/scim/v2/Users"
    end
  end

  describe "collection_url/2 (with scope)" do
    test "falls back to global URL when scope is nil" do
      assert Config.collection_url("Users", nil) == "https://example.com/scim/v2/Users"
    end

    test "falls back to global URL when tenant_id is nil" do
      scope = %Scope{id: "user_1", scopes: [], tenant_id: nil}
      assert Config.collection_url("Users", scope) == "https://example.com/scim/v2/Users"
    end
  end
end
