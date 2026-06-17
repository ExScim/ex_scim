defmodule ExScimPhoenix.Test.TestAuth do
  @moduledoc """
  Auth provider adapter for controller pipeline tests.

  Maps fixed bearer tokens to scopes so tests can exercise the full
  authentication + authorization path:

  - `"token-all"` - all SCIM scopes (read/create/update/delete)
  - `"token-readonly"` - only `scim:read`
  - `"token-noscope"` - authenticated but no scopes (for 403 tests)
  - `"token-me"` - all scopes, scope id `"me-user"` (for `/Me` tests)

  Any other token returns `{:error, :token_not_found}` (401). Basic auth is
  always rejected.
  """

  @behaviour ExScim.Auth.AuthProvider.Adapter

  alias ExScim.Scope

  @crud_scopes ["scim:read", "scim:create", "scim:update", "scim:delete"]
  @me_scopes ["scim:me:read", "scim:me:create", "scim:me:update", "scim:me:delete"]
  @all_scopes @crud_scopes ++ @me_scopes

  @impl true
  def validate_bearer("token-all"), do: {:ok, %Scope{id: "client-all", scopes: @all_scopes}}
  def validate_bearer("token-readonly"), do: {:ok, %Scope{id: "client-ro", scopes: ["scim:read"]}}
  def validate_bearer("token-noscope"), do: {:ok, %Scope{id: "client-none", scopes: []}}
  def validate_bearer("token-me"), do: {:ok, %Scope{id: "me-user", scopes: @me_scopes}}

  def validate_bearer("token-me-claims") do
    {:ok,
     %Scope{
       id: "me-user",
       scopes: @me_scopes,
       metadata: %{
         claims: %{
           "preferred_username" => "claims.user",
           "email" => "claims@test.com",
           "given_name" => "Claims",
           "family_name" => "User",
           "sub" => "sub-123"
         }
       }
     }}
  end

  def validate_bearer("token-me-userinfo") do
    {:ok,
     %Scope{
       id: "me-user",
       scopes: @me_scopes,
       metadata: %{
         user_info: %{subject: "subj-456", username: "userinfo.user", email: "userinfo@test.com"}
       }
     }}
  end

  def validate_bearer(_), do: {:error, :token_not_found}

  @impl true
  def validate_basic(_username, _password), do: {:error, :invalid_credentials}
end
