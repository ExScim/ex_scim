defmodule ExScimPhoenix.Controller.BulkController do
  @moduledoc """
  SCIM 2.0 Bulk Operations Controller implementing RFC 7644 Section 3.7.

  Handles bulk create, update, patch, and delete operations with proper
  error handling and transaction support.
  """

  use Phoenix.Controller, formats: [:json]
  require Logger
  import ExScimPhoenix.ErrorResponse

  alias ExScim.Operations.Bulk
  alias ExScim.Config

  plug(
    ExScimPhoenix.Plugs.RequireScopes,
    [scopes: ["scim:write"]] when action in [:bulk]
  )

  # Default configuration values
  @default_max_operations 1000
  # 1MB
  @default_max_payload_size 1_048_576
  # Continue on errors by default
  @default_fail_on_errors 0

  def bulk(conn, bulk_request) do
    caller = conn.assigns.scim_scope

    # Get configuration from application config
    bulk_config = get_bulk_config()
    base_url = Config.base_url()

    # Parse bulk operation parameters from request
    opts = [
      fail_on_errors: parse_fail_on_errors(bulk_request),
      max_operations: bulk_config.max_operations,
      max_payload_size: bulk_config.max_payload_size,
      base_url: base_url
    ]

    case Bulk.process_bulk_request(bulk_request, caller, opts) do
      {:ok, bulk_response} ->
        # Determine overall status based on individual operation results
        status_code = determine_bulk_status(bulk_response["Operations"])

        conn
        |> put_status(status_code)
        |> json(bulk_response)

      {:error, reason} when is_binary(reason) ->
        send_scim_error(conn, :bad_request, :invalid_syntax, reason)

      {:error, reason} ->
        Logger.error("Bulk operation error: #{inspect(reason)}")
        send_scim_error(conn, :bad_request, :invalid_value, "Invalid bulk request")
    end
  end

  # Private helper functions

  defp get_bulk_config do
    %{
      max_operations:
        Application.get_env(:ex_scim, :bulk_max_operations, @default_max_operations),
      max_payload_size:
        Application.get_env(:ex_scim, :bulk_max_payload_size, @default_max_payload_size),
      supported: Application.get_env(:ex_scim, :bulk_supported, true)
    }
  end

  defp parse_fail_on_errors(bulk_request) do
    case Map.get(bulk_request, "failOnErrors") do
      nil -> @default_fail_on_errors
      value when is_integer(value) and value >= 0 -> value
      _ -> @default_fail_on_errors
    end
  end

  defp determine_bulk_status(operations) do
    has_errors =
      Enum.any?(operations, fn op ->
        status = String.to_integer(op["status"] || "200")
        status >= 400
      end)

    # Always return 200 for bulk operations per RFC
    if has_errors, do: :ok, else: :ok
  end
end
