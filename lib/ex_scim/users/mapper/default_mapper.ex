defmodule ExScim.Users.Mapper.DefaultMapper do
  @moduledoc """
  Default mapper implementation for basic SCIM compliance.
  """

  @behaviour ExScim.Users.Mapper.Adapter

  @scim_user_schema "urn:ietf:params:scim:schemas:core:2.0:User"

  @impl true
  def from_scim(scim_data) do
    %{
      id: scim_data["id"],
      external_id: scim_data["externalId"],
      user_name: scim_data["userName"],
      active: scim_data["active"] || true,
      name: scim_data["name"],
      display_name: scim_data["displayName"],
      emails: scim_data["emails"] || [],
      meta: scim_data["meta"] || %{},
      schemas: scim_data["schemas"] || [@scim_user_schema]
    }
  end

  @impl true
  def to_scim(user, opts \\ []) do
    location = Keyword.get(opts, :location)

    %{
      "schemas" => user.schemas,
      "id" => user.id,
      "externalId" => user.external_id,
      "userName" => user.user_name,
      "active" => user.active,
      "name" => user.name,
      "displayName" => user.display_name,
      "emails" => user.emails,
      "meta" => user.meta,
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
