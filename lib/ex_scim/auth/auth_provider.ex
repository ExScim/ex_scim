defmodule ExScim.Auth.AuthProvider do
  @behaviour ExScim.Auth.AuthProvider.Adapter

  @impl true
  def validate_bearer(token) do
    adapter().validate_bearer(token)
  end

  @impl true
  def validate_basic(username, password) do
    adapter().validate_basic(username, password)
  end

  def adapter do
    Application.fetch_env!(:ex_scim, :auth_provider_adapter)
  end
end
