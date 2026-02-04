defmodule Provider.Scim.UserMapper do
  @moduledoc """
  Maps between SCIM format and Provider.Accounts.User domain struct.
  """

  use ExScim.Users.Mapper.Adapter

  alias Provider.Accounts.User
  alias ExScim.Config

  @impl true
  def from_scim(scim_data, _caller) do
    {:ok,
     %User{
       user_name: scim_data["userName"],
       given_name: get_in(scim_data, ["name", "givenName"]),
       family_name: get_in(scim_data, ["name", "familyName"]),
       display_name: scim_data["displayName"],
       email: get_primary_email(scim_data["emails"]),
       active: Map.get(scim_data, "active", true),
       external_id: scim_data["externalId"] || scim_data["userName"],
       meta_created: parse_datetime(get_in(scim_data, ["meta", "created"])),
       meta_last_modified: parse_datetime(get_in(scim_data, ["meta", "lastModified"]))
     }}
  end

  @impl true
  def to_scim(%User{} = user, _caller, opts \\ []) do
    location =
      Keyword.get_lazy(opts, :location, fn ->
        Config.resource_url("Users", user.id)
      end)

    {:ok,
     %{
       "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
       "id" => user.id,
       "externalId" => user.external_id,
       "userName" => user.user_name,
       "displayName" => user.display_name,
       "active" => user.active,
       "emails" => format_emails(user.email),
       "name" => format_name(user),
       "meta" => format_meta(user, location: location, resource_type: "User")
     }}
  end

  # Domain-specific helpers

  defp get_primary_email(emails) when is_list(emails) do
    case Enum.find(emails, &Map.get(&1, "primary", false)) || List.first(emails) do
      %{"value" => email} -> email
      _ -> nil
    end
  end

  defp get_primary_email(_), do: nil

  defp format_emails(nil), do: []

  defp format_emails(email) when is_binary(email) do
    [%{"value" => email, "primary" => true}]
  end

  defp format_name(%User{given_name: given_name, family_name: family_name}) do
    formatted =
      case {given_name, family_name} do
        {nil, nil} -> nil
        {given, nil} -> given
        {nil, family} -> family
        {given, family} -> "#{given} #{family}"
      end

    %{
      "givenName" => given_name,
      "familyName" => family_name,
      "formatted" => formatted
    }
  end
end
