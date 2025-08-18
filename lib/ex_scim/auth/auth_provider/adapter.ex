defmodule ExScim.Auth.AuthProvider.Adapter do
  @moduledoc "SCIM authentication provider behaviour."

  alias ExScim.Auth.Principal

  @callback validate_bearer(token :: String.t()) ::
              {:ok, Principal.t()} | {:error, term()}

  @callback validate_basic(username :: String.t(), password :: String.t()) ::
              {:ok, Principal.t()} | {:error, term()}
end
