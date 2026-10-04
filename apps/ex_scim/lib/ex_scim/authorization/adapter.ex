defmodule ExScim.Authorization.Adapter do
  @moduledoc """
  Implements an authorization policy and decides whether an authenticated
  `ExScim.Scope` may perform an action on a resource.
  """
  alias ExScim.Scope

  @type resource ::
          :users | :groups | :me | :schemas | :resource_types | :service_provider_config

  @type action :: :read | :create | :update | :delete

  @typedoc "Indicate missing scopes or other reason for denying access."
  @type denial :: {:missing_scopes, [String.t()]} | term()

  @doc "Returns `:ok` when `scope` may perform `action` on `resource`, `{:error, denial}` otherwise."
  @callback authorize(scope :: Scope.t(), resource(), action()) :: :ok | {:error, denial()}
end
