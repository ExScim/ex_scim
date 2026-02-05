defmodule ExScim.Schema.Repository.DefaultRepository do
  @moduledoc """
  Default SCIM schema repository that loads schemas from configured modules.

  This repository dynamically loads schema definitions from modules configured
  via `:ex_scim, :schema_modules`. Each module must use the `ExScim.Schema.Builder`
  DSL and provide `schema_id/0` and `to_map/0` functions.

  ## Configuration

      config :ex_scim, :schema_modules, [
        MyApp.Schemas.User,
        MyApp.Schemas.Group
      ]

  ## Default Schemas

  When not configured, uses the built-in definitions:

  - `ExScim.Schema.Definitions.User`
  - `ExScim.Schema.Definitions.EnterpriseUser`
  - `ExScim.Schema.Definitions.Group`
  """

  @behaviour ExScim.Schema.Repository.Adapter

  @impl true
  def get_schema(schema_uri) do
    case find_module_by_schema_id(schema_uri) do
      nil -> {:error, :not_found}
      module -> {:ok, module.to_map()}
    end
  end

  @impl true
  def list_schemas do
    ExScim.Config.schema_modules()
    |> Enum.map(& &1.to_map())
  end

  @impl true
  def has_schema?(schema_uri) do
    find_module_by_schema_id(schema_uri) != nil
  end

  defp find_module_by_schema_id(schema_uri) do
    ExScim.Config.schema_modules()
    |> Enum.find(fn module -> module.schema_id() == schema_uri end)
  end
end
