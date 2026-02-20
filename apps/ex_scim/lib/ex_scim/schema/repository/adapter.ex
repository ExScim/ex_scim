defmodule ExScim.Schema.Repository.Adapter do
  @moduledoc """
  Behaviour for SCIM schema repositories.

  Stores and retrieves SCIM schema definitions (RFC 7643 Section 7) used by
  the `/Schemas` discovery endpoint. The default implementation uses
  `ExScim.Schema.Builder` to construct schemas from Elixir DSL definitions.
  """

  @typedoc "A SCIM schema URI, e.g. `\"urn:ietf:params:scim:schemas:core:2.0:User\"`."
  @type schema_uri :: binary()

  @typedoc "A SCIM schema definition as a JSON-compatible map."
  @type schema :: map()

  @doc "Retrieves a schema by its URI. Returns `{:ok, schema}` or `{:error, :not_found}`."
  @callback get_schema(schema_uri()) :: {:ok, schema()} | {:error, :not_found}

  @doc "Returns all registered schemas."
  @callback list_schemas() :: [schema()]

  @doc "Returns `true` if a schema with the given URI is registered."
  @callback has_schema?(schema_uri()) :: boolean()
end
