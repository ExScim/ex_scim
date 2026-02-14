defmodule ExScimPhoenix.Plugs.ScimTenant do
  @moduledoc """
  Plug for resolving tenant context from the request.

  Place this plug AFTER `ScimAuth` in the pipeline. It calls the configured
  `ExScim.Tenant.Resolver` to determine the tenant, then sets `scope.tenant_id`.

  When no resolver is configured, this plug is a no-op.

  ## Configuration

      config :ex_scim, tenant_resolver: MyApp.TenantResolver

  ## Pipeline example

      pipeline :scim do
        plug ExScimPhoenix.Plugs.ScimAuth
        plug ExScimPhoenix.Plugs.ScimTenant
      end
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case resolver() do
      nil ->
        conn

      resolver_mod ->
        scope = conn.assigns[:scim_scope]

        case resolver_mod.resolve_tenant(conn, scope) do
          {:ok, tenant_id} ->
            assign(conn, :scim_scope, %{scope | tenant_id: tenant_id})

          {:error, reason} ->
            send_tenant_error(conn, reason)
        end
    end
  end

  defp resolver do
    Application.get_env(:ex_scim, :tenant_resolver)
  end

  defp send_tenant_error(conn, reason) do
    detail =
      case reason do
        :missing_tenant -> "Tenant identifier required"
        :invalid_tenant -> "Invalid tenant identifier"
        msg when is_binary(msg) -> msg
        _ -> "Tenant resolution failed"
      end

    error_response = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "status" => "403",
      "detail" => detail
    }

    conn
    |> put_status(403)
    |> json(error_response)
    |> halt()
  end
end
