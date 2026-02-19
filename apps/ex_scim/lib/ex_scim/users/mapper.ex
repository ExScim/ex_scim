defmodule ExScim.Users.Mapper do
  @moduledoc """
  Converts between domain user structs and SCIM JSON representations.

  Delegates to the configured mapper adapter. Falls back to
  `ExScim.Users.Mapper.DefaultMapper` when no adapter is configured.

  ## Configuration

      config :ex_scim, user_resource_mapper: MyApp.UserMapper
  """

  @doc """
  Converts a SCIM JSON map into a domain user struct.

  The `scope` provides tenant/caller context for the conversion.
  """
  @spec from_scim(map(), ExScim.Scope.t()) ::
          {:ok, struct() | map()} | {:error, atom() | term()}
  def from_scim(scim_data, caller) do
    adapter().from_scim(scim_data, caller)
  end

  @doc """
  Converts a domain user struct into a SCIM JSON map.

  The `scope` provides tenant/caller context. `opts` are passed through
  to the adapter (e.g. for controlling which fields to include).
  """
  @spec to_scim(struct() | map(), ExScim.Scope.t(), keyword()) ::
          {:ok, map()} | {:error, atom() | term()}
  def to_scim(user_struct, caller, opts \\ []) do
    adapter().to_scim(user_struct, caller, opts)
  end

  @doc "Returns the configured user mapper adapter module."
  def adapter do
    Application.get_env(
      :ex_scim,
      :user_resource_mapper,
      ExScim.Users.Mapper.DefaultMapper
    )
  end
end
