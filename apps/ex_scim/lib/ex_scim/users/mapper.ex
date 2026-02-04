defmodule ExScim.Users.Mapper do
  @spec from_scim(map(), ExScim.Auth.Principal.t()) ::
          {:ok, struct() | map()} | {:error, atom() | term()}
  def from_scim(scim_data, caller) do
    adapter().from_scim(scim_data, caller)
  end

  @spec to_scim(struct() | map(), ExScim.Auth.Principal.t(), keyword()) ::
          {:ok, map()} | {:error, atom() | term()}
  def to_scim(user_struct, caller, opts \\ []) do
    adapter().to_scim(user_struct, caller, opts)
  end

  def adapter do
    Application.get_env(
      :ex_scim,
      :user_resource_mapper,
      ExScim.Users.Mapper.DefaultMapper
    )
  end
end
