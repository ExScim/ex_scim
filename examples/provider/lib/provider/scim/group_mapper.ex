defmodule Provider.Scim.GroupMapper do
  @moduledoc """
  Maps between SCIM format and Provider.Accounts.Group domain struct.
  """

  use ExScim.Groups.Mapper.Adapter

  alias Provider.Accounts.Group
  alias ExScim.Config

  @impl true
  def from_scim(scim_data, _caller) do
    {:ok,
     %Group{
       display_name: scim_data["displayName"],
       description: scim_data["description"] || scim_data["displayName"],
       external_id: scim_data["externalId"] || scim_data["displayName"],
       active: Map.get(scim_data, "active", true),
       meta_created: parse_datetime(get_in(scim_data, ["meta", "created"])),
       meta_last_modified: parse_datetime(get_in(scim_data, ["meta", "lastModified"]))
     }}
  end

  @impl true
  def to_scim(%Group{} = group, _caller, opts \\ []) do
    location =
      Keyword.get_lazy(opts, :location, fn ->
        Config.resource_url("Groups", group.id)
      end)

    {:ok,
     %{
       "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
       "id" => group.id,
       "externalId" => group.external_id,
       "displayName" => group.display_name,
       "description" => group.description,
       "active" => group.active,
       "members" => format_members(group),
       "meta" => format_meta(group, location: location, resource_type: "Group")
     }}
  end

  # Domain-specific helper

  defp format_members(%Group{users: users}) when is_list(users) do
    Enum.map(users, fn user ->
      %{
        "value" => user.id,
        "display" => user.display_name || user.user_name,
        "$ref" => Config.resource_url("Users", user.id),
        "type" => "User"
      }
    end)
  end

  defp format_members(_), do: []
end
