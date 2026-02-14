defmodule Provider.Scim.FakeAuthProvider do
  @behaviour ExScim.Auth.AuthProvider.Adapter
  alias ExScim.Scope

  defp fake_tokens do
    %{
      "valid_bearer_token_123" => %{
        id: "scim_client_1",
        scopes: ["scim:read", "scim:write"],
        expires_at: DateTime.utc_now() |> DateTime.add(2, :day),
        active: true,
        metadata: %{
          client_name: "Okta SCIM Provisioner",
          grant_type: "client_credentials"
        }
      },
      "valid_user_token" => %{
        id: "263675ec-fb54-4229-add0-815d10532625",
        scopes: [
          "scim:me:read",
          "scim:me:create",
          "scim:me:update",
          "scim:me:delete",
          "scim:read",
          "scim:write"
        ],
        expires_at: DateTime.utc_now() |> DateTime.add(2, :day),
        active: true,
        metadata: %{
          claims: %{
            "sub" => "263675ec-fb54-4229-add0-815d10532625",
            "preferred_username" => "jane.doe",
            "given_name" => "Jane",
            "family_name" => "Doe",
            "email" => "jane.doe@example.com",
            "email_verified" => true
          }
        }
      },
      "expired_token_456" => %{
        id: "scim_client_2",
        scopes: ["scim:read"],
        expires_at: DateTime.utc_now() |> DateTime.add(1, :day),
        active: false,
        metadata: %{
          client_name: "Expired Client",
          grant_type: "client_credentials"
        }
      }
    }
  end

  defp fake_credentials do
    %{
      {"scim_user", "scim_password123"} => %{
        id: "scim_client_basic",
        scopes: ["scim:read", "scim:write"],
        display_name: "SCIM Basic Auth Client",
        metadata: %{auth_method: :basic}
      },
      {"readonly_user", "readonly_pass"} => %{
        id: "scim_client_readonly",
        scopes: ["scim:read"],
        display_name: "SCIM Read-Only Client",
        metadata: %{auth_method: :basic}
      },
      {"scim", "scim"} => %{
        id: "scim_compliance_test",
        scopes: ["scim:read", "scim:write"],
        display_name: "SCIM Compliance Test Client",
        metadata: %{auth_method: :basic}
      }
    }
  end

  @impl true
  def validate_bearer(token) do
    case Map.get(fake_tokens(), token) do
      %{active: true, expires_at: exp} = data ->
        if DateTime.compare(DateTime.utc_now(), exp) == :lt do
          Scope.new(data)
        else
          {:error, :expired_token}
        end

      %{active: false} ->
        {:error, :inactive_token}

      nil ->
        {:error, :token_not_found}
    end
  end

  @impl true
  def validate_basic(username, password) do
    case Map.get(fake_credentials(), {username, password}) do
      nil ->
        {:error, :invalid_credentials}

      data ->
        Scope.new(Map.put(data, :username, username))
    end
  end
end
