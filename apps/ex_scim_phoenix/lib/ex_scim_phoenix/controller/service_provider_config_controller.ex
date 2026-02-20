defmodule ExScimPhoenix.Controller.ServiceProviderConfigController do
  @moduledoc """
  Serves the SCIM ServiceProviderConfig endpoint (RFC 7643 Section 5).

  Returns server capabilities including supported operations, authentication
  schemes, and feature flags like bulk, filter, and patch support.
  """

  use Phoenix.Controller, formats: [:json]

  alias ExScim.Config

  plug(ExScimPhoenix.Plugs.RequireScopes, [scopes: ["scim:read"]] when action in [:show])

  @doc false
  def show(conn, _params) do
    bulk_supported = Config.bulk_supported()
    filter_supported = Config.filter_supported()

    config =
      %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"],
        "patch" => %{"supported" => Config.patch_supported()},
        "bulk" => build_bulk(bulk_supported),
        "filter" => build_filter(filter_supported),
        "changePassword" => %{"supported" => Config.change_password_supported()},
        "sort" => %{"supported" => Config.sort_supported()},
        "etag" => %{"supported" => Config.etag_supported()},
        "authenticationSchemes" => Config.authentication_schemes()
      }
      |> maybe_put("documentationUri", Config.documentation_uri())

    json(conn, config)
  end

  defp build_bulk(true) do
    %{
      "supported" => true,
      "maxOperations" => Config.bulk_max_operations(),
      "maxPayloadSize" => Config.bulk_max_payload_size()
    }
  end

  defp build_bulk(false), do: %{"supported" => false}

  defp build_filter(true) do
    %{
      "supported" => true,
      "maxResults" => Config.filter_max_results()
    }
  end

  defp build_filter(false), do: %{"supported" => false}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
