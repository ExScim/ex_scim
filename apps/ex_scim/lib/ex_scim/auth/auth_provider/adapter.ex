defmodule ExScim.Auth.AuthProvider.Adapter do
  @moduledoc """
  Behaviour for SCIM authentication providers.

  Implementations must handle two authentication methods:

  - **Bearer token** - validates an OAuth2/API token from the `Authorization: Bearer <token>` header
  - **HTTP Basic** - validates a username/password pair from the `Authorization: Basic <credentials>` header

  Both callbacks must return `{:ok, scope}` on success, where `scope` is an
  `ExScim.Scope` struct that carries tenant and permission information through
  the request pipeline.

  ## Configuration

      config :ex_scim, auth_provider_adapter: MyApp.ScimAuth
  """

  alias ExScim.Scope

  @typedoc """
  Authentication error reasons.

  Common values:

  - `:invalid_credentials` - username/password do not match
  - `:token_not_found` - bearer token does not exist
  - `:expired_token` - bearer token has expired
  - `:inactive_token` - bearer token is revoked or disabled
  - `:invalid_basic_format` - malformed basic auth header

  Custom atoms are also allowed.
  """
  @type auth_error ::
          :invalid_credentials
          | :token_not_found
          | :expired_token
          | :inactive_token
          | :invalid_basic_format
          | atom()

  @doc "Validates an OAuth2/API bearer token. Returns `{:ok, scope}` or `{:error, auth_error}`."
  @callback validate_bearer(token :: String.t()) ::
              {:ok, Scope.t()} | {:error, auth_error()}

  @doc "Validates HTTP basic auth credentials. Returns `{:ok, scope}` or `{:error, auth_error}`."
  @callback validate_basic(username :: String.t(), password :: String.t()) ::
              {:ok, Scope.t()} | {:error, auth_error()}
end
