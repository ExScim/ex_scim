defmodule ExScim.Groups.Mapper.DefaultMapper do
  @moduledoc """
  Default mapper implementation for basic SCIM group compliance.
  """

  @behaviour ExScim.Groups.Mapper.Adapter

  @scim_group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"

  @impl true
  def from_scim(scim_data) do
    %{
      id: scim_data["id"],
      external_id: scim_data["externalId"],
      display_name: scim_data["displayName"],
      members: scim_data["members"] || [],
      meta: scim_data["meta"] || %{},
      schemas: scim_data["schemas"] || [@scim_group_schema]
    }
  end

  @impl true
  def to_scim(group, opts \\ []) do
    location = Keyword.get(opts, :location)

    %{
      "schemas" => group.schemas,
      "id" => group.id,
      "externalId" => group.external_id,
      "displayName" => group.display_name,
      "members" => group.members,
      "meta" => group.meta,
      "location" => location
    }
    |> remove_nil_values()
  end

  defp remove_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
