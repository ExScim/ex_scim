defmodule ExScim.Auth.AuthProvider do
  @moduledoc """
  Delegates authentication calls to the configured adapter.

  Supports bearer token and HTTP basic authentication. The adapter is resolved
  at runtime from the `:auth_provider_adapter` application config.

  ## Configuration

      config :ex_scim, auth_provider_adapter: MyApp.ScimAuth
  """

  @behaviour ExScim.Auth.AuthProvider.Adapter

  @doc """
  Validates a bearer token and returns the authenticated scope.

  Returns `{:ok, scope}` on success or `{:error, reason}` on failure.
  """
  @impl true
  def validate_bearer(token) do
    adapter().validate_bearer(token)
  end

  @doc """
  Validates HTTP basic auth credentials and returns the authenticated scope.

  Returns `{:ok, scope}` on success or `{:error, reason}` on failure.
  """
  @impl true
  def validate_basic(username, password) do
    adapter().validate_basic(username, password)
  end

  @doc "Returns the configured auth provider adapter module."
  def adapter do
    Application.fetch_env!(:ex_scim, :auth_provider_adapter)
  end
end
