defmodule ExScim.Authorization do
  @moduledoc """
  Public entry point for SCIM authorization decisions.

  Delegates to the configured `authorization_adapter` (see `ExScim.Authorization.Adapter`).

  When no adapter is configured, `ExScim.Authorization.DefaultPolicy` is used.
  """

  alias ExScim.Authorization.Adapter

  @doc "Returns `:ok` when `scope` may perform `action` on `resource`, `{:error, denial}` otherwise."
  @spec authorize(ExScim.Scope.t(), Adapter.resource(), Adapter.action()) ::
          :ok | {:error, Adapter.denial()}
  def authorize(scope, resource, action) do
    adapter().authorize(scope, resource, action)
  end

  @doc "Formats a denial as a human-readable error detail."
  @spec denial_detail(Adapter.denial()) :: String.t()
  def denial_detail({:missing_scopes, scopes}),
    do: "Missing required scope(s): #{Enum.join(scopes, ", ")}"

  def denial_detail(_reason), do: "Operation is not permitted based on the supplied authorization"

  @doc "Returns the configured authorization adapter module."
  @spec adapter() :: module()
  def adapter do
    Application.get_env(:ex_scim, :authorization_adapter, ExScim.Authorization.DefaultPolicy)
  end
end
