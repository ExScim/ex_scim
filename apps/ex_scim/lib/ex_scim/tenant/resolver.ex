defmodule ExScim.Tenant.Resolver do
  @moduledoc """
  Behaviour for resolving tenant context from an incoming request.

  Implement this behaviour to extract a tenant identifier from the connection
  (e.g., from a header, path segment, subdomain, or the authenticated scope).

  ## Configuration

      config :ex_scim, tenant_resolver: MyApp.TenantResolver

  When not configured, no tenant resolution happens and the system operates
  in single-tenant mode.

  ## Example

      defmodule MyApp.TenantResolver do
        @behaviour ExScim.Tenant.Resolver

        @impl true
        def resolve_tenant(conn, _scope) do
          case Plug.Conn.get_req_header(conn, "x-tenant-id") do
            [tenant_id] -> {:ok, tenant_id}
            _ -> {:error, :missing_tenant}
          end
        end
      end

  ## Optional: Tenant-aware URLs

  If your resolver also implements `tenant_scim_base_url/1`, it will be used
  for generating resource location URLs scoped to the tenant.

      @impl true
      def tenant_scim_base_url(tenant_id) do
        "https://\#{tenant_id}.example.com/scim/v2"
      end
  """

  @callback resolve_tenant(conn :: Plug.Conn.t(), scope :: ExScim.Scope.t() | nil) ::
              {:ok, String.t()} | {:error, term()}

  @callback tenant_scim_base_url(tenant_id :: String.t()) :: String.t()

  @optional_callbacks [tenant_scim_base_url: 1]
end
