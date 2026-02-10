defmodule ExScimPhoenix.Controller.ResourceTypeController do
  use Phoenix.Controller, formats: [:json]

  @moduledoc """
  SCIM v2.0 ResourceType endpoint implementation (RFC 7644 Section 4)
  Provides metadata about the resource types supported by the service provider.

  Resource types are read from `ExScim.Config.resource_types/0`, which defaults
  to User (with Enterprise extension) and Group when not explicitly configured.
  """

  def index(conn, _params) do
    resource_types = build_resource_types()

    response = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
      "totalResults" => length(resource_types),
      "startIndex" => 1,
      "itemsPerPage" => length(resource_types),
      "Resources" => resource_types
    }

    conn
    |> put_resp_content_type("application/scim+json")
    |> json(response)
  end

  def show(conn, %{"id" => id}) do
    resource_types = build_resource_types()

    case find_resource_type(resource_types, id) do
      nil ->
        error_response = %{
          "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
          "detail" => "Resource #{id} not found",
          "status" => "404"
        }

        conn
        |> put_status(:not_found)
        |> put_resp_content_type("application/scim+json")
        |> json(error_response)

      resource_type ->
        conn
        |> put_resp_content_type("application/scim+json")
        |> json(resource_type)
    end
  end

  defp build_resource_types do
    base_url = ExScim.Config.base_url()

    ExScim.Config.resource_types()
    |> Enum.map(fn rt ->
      resource_type = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:ResourceType"],
        "id" => rt.id,
        "name" => rt.name,
        "endpoint" => rt.endpoint,
        "description" => rt.description,
        "schema" => rt.schema,
        "meta" => %{
          "location" => "#{base_url}/scim/v2/ResourceTypes/#{rt.id}",
          "resourceType" => "ResourceType"
        }
      }

      case rt.schema_extensions do
        [] -> resource_type
        extensions ->
          Map.put(resource_type, "schemaExtensions",
            Enum.map(extensions, fn ext ->
              %{"schema" => ext.schema, "required" => ext.required}
            end)
          )
      end
    end)
  end

  defp find_resource_type(resource_types, id) do
    Enum.find(resource_types, fn rt -> rt["id"] == id end)
  end
end
