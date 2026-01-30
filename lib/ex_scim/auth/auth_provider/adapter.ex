defmodule ExScim.Auth.AuthProvider.Adapter do
  @moduledoc "SCIM authentication provider behaviour."

  alias ExScim.Auth.Principal

  @type auth_error ::
          :invalid_credentials
          | :token_not_found
          | :expired_token
          | :inactive_token
          | :invalid_basic_format
          | atom()

  @callback validate_bearer(token :: String.t()) ::
              {:ok, Principal.t()} | {:error, auth_error()}

  @callback validate_basic(username :: String.t(), password :: String.t()) ::
              {:ok, Principal.t()} | {:error, auth_error()}
end
