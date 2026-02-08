defmodule ExScimPhoenix.Controller.UserController do
  @moduledoc """
  SCIM 2.0 User Controller with configurable storage and user types.
  """

  use Phoenix.Controller, formats: [:json]
  require Logger
  import ExScimPhoenix.ErrorResponse

  alias ExScim.Operations.Users

  plug(
    ExScimPhoenix.Plugs.RequireScopes,
    [scopes: ["scim:read"]] when action in [:index, :show, :search]
  )

  plug(
    ExScimPhoenix.Plugs.RequireScopes,
    [scopes: ["scim:write"]] when action in [:create, :update, :patch, :delete]
  )

  @scim_list_response_schema "urn:ietf:params:scim:api:messages:2.0:ListResponse"

  # Default pagination values
  @default_start_index 1
  @default_count 20
  @max_count 200

  def index(conn, params) do
    caller = conn.assigns.scim_principal

    with {:ok, parsed_params} <- parse_list_params(params),
         {:ok, users, total_results} <- Users.list_users_scim(caller, parsed_params) do
      response = %{
        "schemas" => [@scim_list_response_schema],
        "totalResults" => total_results,
        "startIndex" => parsed_params.start_index,
        "itemsPerPage" => length(users),
        "Resources" => users
      }

      json(conn, response)
    else
      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, reason} ->
        send_scim_error(conn, :bad_request, :invalid_filter, "Invalid query: #{reason}")
    end
  end

  def show(conn, %{"id" => id}) do
    caller = conn.assigns.scim_principal

    case Users.get_user(id, caller) do
      {:ok, user} ->
        json(conn, user)

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "User #{id} not found")

      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, reason} ->
        Logger.error("Error retrieving user #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def create(conn, user_params) do
    caller = conn.assigns.scim_principal

    case Users.create_user_from_scim(user_params, caller) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> maybe_put_resp_header("location", get_in(user, ["meta", "location"]))
        |> maybe_put_resp_header("etag", get_in(user, ["meta", "etag"]))
        |> json(user)

      {:error, :conflict} ->
        send_scim_error(conn, :conflict, :uniqueness, "User already exists")

      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error creating user: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def update(conn, %{"id" => id} = user_params) do
    caller = conn.assigns.scim_principal
    # Remove id from params to avoid conflicts
    user_params = Map.delete(user_params, "id")

    case Users.replace_user_from_scim(id, user_params, caller) do
      {:ok, user} ->
        conn
        |> maybe_put_resp_header("etag", get_in(user, ["meta", "etag"]))
        |> json(user)

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "User #{id} not found")

      {:error, :conflict} ->
        send_scim_error(conn, :conflict, :uniqueness, "User data conflicts with existing user")

      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error updating user #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def patch(conn, %{"id" => id} = patch_params) do
    caller = conn.assigns.scim_principal
    # Remove id from params to avoid conflicts
    patch_params = Map.delete(patch_params, "id")

    case Users.patch_user_from_scim(id, patch_params, caller) do
      {:ok, user} ->
        conn
        |> maybe_put_resp_header("etag", get_in(user, ["meta", "etag"]))
        |> json(user)

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "User #{id} not found")

      {:error, :invalid_patch_operation} ->
        send_scim_error(conn, :bad_request, :invalid_syntax, "Invalid patch operation")

      {:error, :no_target} ->
        send_scim_error(
          conn,
          :bad_request,
          :no_target,
          "Path attribute did not yield a valid target"
        )

      {:error, :invalid_path} ->
        send_scim_error(
          conn,
          :bad_request,
          :invalid_path,
          "Path attribute is invalid or malformed"
        )

      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error patching user #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def delete(conn, %{"id" => id}) do
    case Users.delete_user(id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "User #{id} not found")

      {:error, reason} ->
        Logger.error("Error deleting user #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  defp parse_list_params(params) do
    with {:ok, start_index} <- parse_integer_param(params, "startIndex", @default_start_index),
         {:ok, count} <- parse_integer_param(params, "count", @default_count),
         {:ok, validated_count} <- validate_count(count),
         {:ok, filter} <- parse_filter_param(params),
         {:ok, attributes} <- parse_attributes_param(params, "attributes"),
         {:ok, excluded_attributes} <- parse_attributes_param(params, "excludedAttributes"),
         {:ok, sort_by} <- parse_sort_param(params, "sortBy"),
         {:ok, sort_order} <- parse_sort_order_param(params, "sortOrder") do
      parsed_params = %{
        start_index: start_index,
        count: validated_count,
        filter: filter,
        attributes: attributes,
        excluded_attributes: excluded_attributes,
        sort_by: sort_by,
        sort_order: sort_order
      }

      {:ok, parsed_params}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_integer_param(params, key, default) do
    case Map.get(params, key) do
      nil ->
        {:ok, default}

      value when is_integer(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_value, ""} when int_value > 0 -> {:ok, int_value}
          _ -> {:error, "#{key} must be a positive integer"}
        end

      _ ->
        {:error, "#{key} must be a positive integer"}
    end
  end

  defp validate_count(count) when count > @max_count do
    {:ok, @max_count}
  end

  defp validate_count(count) when count >= 0 do
    {:ok, count}
  end

  defp validate_count(count) when count < 0 do
    # RFC 7644: "A negative value SHALL be interpreted as '0'"
    {:ok, 0}
  end

  defp validate_count(_count) do
    {:error, "count must be a non-negative integer"}
  end

  defp parse_filter_param(params) do
    case Map.get(params, "filter") do
      nil ->
        {:ok, nil}

      "" ->
        {:ok, nil}

      filter when is_binary(filter) ->
        case ExScim.Parser.Filter.filter(filter) do
          {:ok, [ast], "", _, _, _} ->
            {:ok, ast}

          {:error, reason, _rest, _context, _line, _column} ->
            {:error, "Invalid filter syntax: #{reason}"}
        end

      _ ->
        {:error, "filter must be a string"}
    end
  end

  defp parse_attributes_param(params, key) do
    case Map.get(params, key) do
      nil ->
        {:ok, []}

      attributes when is_binary(attributes) ->
        attribute_list =
          attributes
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {:ok, attribute_list}

      _ ->
        {:error, "#{key} must be a comma-separated string"}
    end
  end

  defp parse_sort_param(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, nil}
      sort_field when is_binary(sort_field) -> {:ok, sort_field}
      _ -> {:error, "#{key} must be a string"}
    end
  end

  defp parse_sort_order_param(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, :ascending}
      "ascending" -> {:ok, :ascending}
      "descending" -> {:ok, :descending}
      _ -> {:error, "#{key} must be 'ascending' or 'descending'"}
    end
  end

  defp maybe_put_resp_header(conn, _header, nil), do: conn
  defp maybe_put_resp_header(conn, header, value), do: put_resp_header(conn, header, value)
end
