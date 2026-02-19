defmodule ExScimPhoenix.Controller.SchemaController do
  @moduledoc """
  SCIM v2.0 Schema endpoint implementation (RFC 7644 Section 4)
  Provides schema definitions for SCIM resources.
  """

  use Phoenix.Controller, formats: [:json]

  alias ExScim.Schema.Repository

  plug(
    ExScimPhoenix.Plugs.RequireScopes,
    [scopes: ["scim:read"]] when action in [:index, :show]
  )

  @doc false
  def index(conn, _params) do
    schemas = Repository.list_schemas()

    response = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
      "totalResults" => length(schemas),
      "startIndex" => 1,
      "itemsPerPage" => length(schemas),
      "Resources" => schemas
    }

    conn
    |> put_resp_content_type("application/scim+json")
    |> json(response)
  end

  @doc false
  def show(conn, %{"id" => id}) do
    case Repository.get_schema(id) do
      {:error, :not_found} ->
        error_response = %{
          "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
          "detail" => "Schema #{id} not found",
          "status" => "404"
        }

        conn
        |> put_status(:not_found)
        |> put_resp_content_type("application/scim+json")
        |> json(error_response)

      {:ok, schema} ->
        conn
        |> put_resp_content_type("application/scim+json")
        |> json(schema)
    end
  end
end
