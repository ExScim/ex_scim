defmodule ExScim.Groups.Mapper do
  @behaviour ExScim.Groups.Mapper.Adapter

  @impl true
  def from_scim(scim_data) do
    adapter().from_scim(scim_data)
  end

  @impl true
  def to_scim(group_struct, opts \\ []) do
    adapter().to_scim(group_struct, opts)
  end

  def adapter do
    Application.get_env(
      :ex_scim,
      :group_resource_mapper,
      ExScim.Groups.Mapper.DefaultMapper
    )
  end
end
