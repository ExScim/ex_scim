defmodule ExScim.Users.Mapper.DefaultMapper do
  @moduledoc """
  Default mapper implementation for basic SCIM compliance.

  Works with maps or structs that have standard field names:
  - `:id`, `:external_id`, `:user_name`, `:active`
  - `:name`, `:display_name`, `:emails`
  - `:meta_created`, `:meta_last_modified`
  """

  use ExScim.Users.Mapper.Adapter

  @scim_user_schema "urn:ietf:params:scim:schemas:core:2.0:User"

  @impl true
  def from_scim(scim_data) do
    %{
      id: scim_data["id"],
      external_id: scim_data["externalId"],
      user_name: scim_data["userName"],
      active: Map.get(scim_data, "active", true),
      name: scim_data["name"],
      display_name: scim_data["displayName"],
      emails: scim_data["emails"] || [],
      schemas: scim_data["schemas"] || [@scim_user_schema],
      meta_created: parse_datetime(get_in(scim_data, ["meta", "created"])),
      meta_last_modified: parse_datetime(get_in(scim_data, ["meta", "lastModified"]))
    }
  end

  @impl true
  def to_scim(user, opts \\ []) do
    %{
      "schemas" => Map.get(user, :schemas, [@scim_user_schema]),
      "id" => Map.get(user, :id),
      "externalId" => Map.get(user, :external_id),
      "userName" => Map.get(user, :user_name),
      "active" => Map.get(user, :active, true),
      "name" => Map.get(user, :name),
      "displayName" => Map.get(user, :display_name),
      "emails" => Map.get(user, :emails, []),
      "meta" => format_meta(user, opts)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
