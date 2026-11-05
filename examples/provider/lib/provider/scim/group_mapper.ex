defmodule Provider.Scim.GroupMapper do
  @moduledoc """
  Maps between SCIM format and Provider.Accounts.Group domain struct.

  `members` are stored by ExScim through `Provider.Accounts.GroupMembership`.
  """

  use ExScim.Groups.Mapper.Adapter

  alias Provider.Accounts.Group

  @impl true
  def from_scim(scim_data, _caller) do
    {:ok,
     %Group{
       display_name: scim_data["displayName"],
       description: scim_data["description"] || scim_data["displayName"],
       external_id: scim_data["externalId"] || scim_data["displayName"],
       active: Map.get(scim_data, "active", true)
     }}
  end

  @impl true
  def to_scim(%Group{} = group, _caller, opts \\ []) do
    {:ok,
     %{
       "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
       "id" => group.id,
       "externalId" => group.external_id,
       "displayName" => group.display_name,
       "description" => group.description,
       "active" => group.active,
       "meta" => format_meta(group, Keyword.put(opts, :resource_type, "Group"))
     }}
  end
end
