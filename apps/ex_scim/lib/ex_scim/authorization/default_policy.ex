defmodule ExScim.Authorization.DefaultPolicy do
  @moduledoc """
  Default authorization policy. Used when no `:authorization_adapter` is configured.
  """
  @behaviour ExScim.Authorization.Adapter

  alias ExScim.Scope

  @impl true
  def authorize(scope, resource, action) do
    case required_scopes(resource, action) do
      :denied -> {:error, :not_permitted}
      required -> check(scope, required)
    end
  end

  defp required_scopes(resource, action)
       when resource in [:users, :groups] and action in [:read, :create, :update, :delete],
       do: ["scim:#{action}"]

  defp required_scopes(:me, action) when action in [:read, :create, :update, :delete],
    do: ["scim:me:#{action}"]

  defp required_scopes(resource, :read) when resource in [:schemas, :service_provider_config],
    do: ["scim:read"]

  defp required_scopes(:resource_types, :read), do: []
  defp required_scopes(_resource, _action), do: :denied

  defp check(%Scope{scopes: scopes}, required) do
    case Enum.reject(required, &(&1 in scopes)) do
      [] -> :ok
      missing -> {:error, {:missing_scopes, missing}}
    end
  end
end
