defmodule ExScim.Schema.Repository.Adapter do
  @moduledoc "SCIM schema repository behaviour."

  @type schema_uri :: binary()
  @type schema :: map()

  @callback get_schema(schema_uri()) :: {:ok, schema()} | {:error, :not_found}
  @callback list_schemas() :: [schema()]
  @callback has_schema?(schema_uri()) :: boolean()
end
