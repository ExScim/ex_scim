defmodule ExScim.Groups.Mapper.DefaultMapper do
  @moduledoc """
  Default mapper implementation for basic SCIM group compliance.

  Works with maps or structs that have standard field names:
  - `:id`, `:external_id`, `:display_name`
  - `:members`
  - `:meta_created`, `:meta_last_modified`
  """

  use ExScim.Groups.Mapper.Adapter

  @scim_group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"

  @impl true
  def from_scim(scim_data) do
    %{
      id: scim_data["id"],
      external_id: scim_data["externalId"],
      display_name: scim_data["displayName"],
      members: scim_data["members"] || [],
      schemas: scim_data["schemas"] || [@scim_group_schema],
      meta_created: parse_datetime(get_in(scim_data, ["meta", "created"])),
      meta_last_modified: parse_datetime(get_in(scim_data, ["meta", "lastModified"]))
    }
  end

  @impl true
  def to_scim(group, opts \\ []) do
    %{
      "schemas" => Map.get(group, :schemas, [@scim_group_schema]),
      "id" => Map.get(group, :id),
      "externalId" => Map.get(group, :external_id),
      "displayName" => Map.get(group, :display_name),
      "members" => Map.get(group, :members, []),
      "meta" => format_meta(group, opts)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
