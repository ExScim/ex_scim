defmodule ExScim.Users.Mapper.DefaultMapper do
  @moduledoc "Default user mapper that stores the SCIM representation."

  use ExScim.Users.Mapper.Adapter

  @scim_user_schema "urn:ietf:params:scim:schemas:core:2.0:User"
  @server_attributes ~w(id meta password)

  @impl true
  def from_scim(scim_data, _caller) do
    {:ok, drop_attributes(scim_data, @server_attributes)}
  end

  @impl true
  def to_scim(user, _caller, opts \\ []) do
    scim_data =
      user
      |> Map.filter(fn {key, _value} -> is_binary(key) end)
      |> Map.put_new("schemas", [@scim_user_schema])
      |> Map.put("id", ExScim.Resources.Resource.get_id(user))
      |> Map.put("meta", format_meta(user, opts))
      |> Map.reject(fn {_key, value} -> is_nil(value) end)

    {:ok, scim_data}
  end

  defp drop_attributes(scim_data, names) do
    Map.reject(scim_data, fn {key, _value} -> String.downcase(key) in names end)
  end
end
