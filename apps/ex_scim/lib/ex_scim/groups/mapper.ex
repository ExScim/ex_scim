defmodule ExScim.Groups.Mapper do
  @spec from_scim(map(), ExScim.Scope.t()) ::
          {:ok, struct() | map()} | {:error, atom() | term()}
  def from_scim(scim_data, caller) do
    adapter().from_scim(scim_data, caller)
  end

  @spec to_scim(struct() | map(), ExScim.Scope.t(), keyword()) ::
          {:ok, map()} | {:error, atom() | term()}
  def to_scim(group_struct, caller, opts \\ []) do
    adapter().to_scim(group_struct, caller, opts)
  end

  def adapter do
    Application.get_env(
      :ex_scim,
      :group_resource_mapper,
      ExScim.Groups.Mapper.DefaultMapper
    )
  end
end
