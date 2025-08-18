defmodule ExScim.Users.Mapper do
  @behaviour ExScim.Users.Mapper.Adapter

  @impl true
  def from_scim(scim_data) do
    adapter().from_scim(scim_data)
  end

  @impl true
  def to_scim(user_struct, opts \\ []) do
    adapter().to_scim(user_struct, opts)
  end

  def adapter do
    Application.get_env(
      :ex_scim,
      :user_resource_mapper,
      ExScim.Users.Mapper.DefaultMapper
    )
  end
end
