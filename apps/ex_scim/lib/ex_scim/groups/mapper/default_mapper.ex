defmodule ExScim.Groups.Mapper.DefaultMapper do
  @moduledoc "Default group mapper that stores the SCIM representation."

  use ExScim.Groups.Mapper.Adapter

  @scim_group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"
  @server_attributes ~w(id meta)

  @impl true
  def from_scim(scim_data, _caller) do
    {:ok,
     Map.reject(scim_data, fn {key, _value} -> String.downcase(key) in @server_attributes end)}
  end

  @impl true
  def to_scim(group, _caller, opts \\ []) do
    scim_data =
      group
      |> Map.filter(fn {key, _value} -> is_binary(key) end)
      |> Map.put_new("schemas", [@scim_group_schema])
      |> Map.put("id", ExScim.Resources.Resource.get_id(group))
      |> Map.put("meta", format_meta(group, opts))
      |> Map.reject(fn {_key, value} -> is_nil(value) end)

    {:ok, scim_data}
  end
end
