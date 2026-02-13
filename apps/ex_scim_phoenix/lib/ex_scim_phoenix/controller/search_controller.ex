defmodule ExScimPhoenix.Controller.SearchController do
  @moduledoc """
  SCIM 2.0 controller which handles POST-based queries.
  """

  use Phoenix.Controller, formats: [:json]
  require Logger
  import ExScimPhoenix.ErrorResponse

  alias ExScim.Operations.Users
  alias ExScim.Operations.Groups

  # Default pagination values
  @default_start_index 1
  @default_count 20
  @max_count 200

  @scim_search_request_schema "urn:ietf:params:scim:api:messages:2.0:SearchRequest"
  @scim_list_response_schema "urn:ietf:params:scim:api:messages:2.0:ListResponse"

  def search(conn, search_params) do
    resource_type = determine_resource_type(conn.request_path)
    scope = conn.assigns[:scim_scope]

    with {:ok, validated_params} <- validate_search_request(search_params),
         {:ok, parsed_params} <- parse_search_params(validated_params),
         {:ok, resources, total_results} <- search_by_resource_type(resource_type, scope, parsed_params) do
      response = %{
        "schemas" => [@scim_list_response_schema],
        "totalResults" => total_results,
        "startIndex" => parsed_params.start_index,
        "itemsPerPage" => length(resources),
        "Resources" => resources
      }

      json(conn, response)
    else
      {:error, :invalid_search_request} ->
        send_scim_error(conn, :bad_request, :invalid_syntax, "Invalid search request format")

      {:error, reason} ->
        send_scim_error(conn, :bad_request, :invalid_value, "Invalid search request: #{reason}")
    end
  end

  def search_all(conn, search_params) do
    scope = conn.assigns[:scim_scope]

    with {:ok, validated_params} <- validate_search_request(search_params),
         {:ok, parsed_params} <- parse_search_params(validated_params),
         {:ok, resources, total_results} <- search_all_resources(scope, parsed_params) do
      response = %{
        "schemas" => [@scim_list_response_schema],
        "totalResults" => total_results,
        "startIndex" => parsed_params.start_index,
        "itemsPerPage" => length(resources),
        "Resources" => resources
      }

      json(conn, response)
    else
      {:error, :invalid_search_request} ->
        send_scim_error(conn, :bad_request, :invalid_syntax, "Invalid search request format")

      {:error, reason} ->
        send_scim_error(conn, :bad_request, :invalid_value, "Invalid search request: #{reason}")
    end
  end

  # Private helper functions
  defp validate_search_request(search_params) do
    case search_params do
      %{"schemas" => schemas} when is_list(schemas) ->
        if @scim_search_request_schema in schemas do
          {:ok, search_params}
        else
          {:error, :invalid_search_request}
        end

      # Allow search requests without explicit schema for flexibility
      %{} = params when map_size(params) > 0 ->
        {:ok, params}

      _ ->
        {:error, :invalid_search_request}
    end
  end

  defp parse_search_params(search_params) do
    with {:ok, start_index} <-
           parse_search_integer_param(search_params, "startIndex", @default_start_index),
         {:ok, count} <- parse_search_integer_param(search_params, "count", @default_count),
         {:ok, validated_count} <- validate_count(count),
         {:ok, filter} <- parse_search_filter_param(search_params, "filter"),
         {:ok, attributes} <- parse_search_attributes_param(search_params, "attributes"),
         {:ok, excluded_attributes} <-
           parse_search_attributes_param(search_params, "excludedAttributes"),
         {:ok, sort_by} <- parse_search_string_param(search_params, "sortBy"),
         {:ok, sort_order} <- parse_search_sort_order_param(search_params, "sortOrder") do
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

  defp parse_search_integer_param(params, key, default) do
    case Map.get(params, key) do
      nil ->
        {:ok, default}

      value when is_integer(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_value, ""} -> {:ok, int_value}
          _ -> {:error, "#{key} must be an integer"}
        end

      _ ->
        {:error, "#{key} must be an integer"}
    end
  end

  defp parse_search_string_param(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, nil}
      value when is_binary(value) and value != "" -> {:ok, value}
      "" -> {:ok, nil}
      _ -> {:error, "#{key} must be a string"}
    end
  end

  defp parse_search_filter_param(params, key) do
    case Map.get(params, key) do
      nil ->
        {:ok, nil}

      "" ->
        {:ok, nil}

      filter when is_binary(filter) ->
        case ExScim.Parser.Filter.filter(filter) do
          {:ok, [ast], "", _, _, _} ->
            {:ok, ast}

          {:error, reason, _rest, _context, line, column} ->
            {:error, "Invalid filter syntax at line #{line}, column #{column}: #{reason}"}
        end

      _ ->
        {:error, "#{key} must be a string"}
    end
  end

  defp parse_search_attributes_param(params, key) do
    case Map.get(params, key) do
      nil ->
        {:ok, []}

      attributes when is_list(attributes) ->
        # Already parsed as list
        attribute_list =
          attributes
          |> Enum.map(fn attr ->
            if is_binary(attr), do: String.trim(attr), else: to_string(attr)
          end)
          |> Enum.reject(&(&1 == ""))

        {:ok, attribute_list}

      attributes when is_binary(attributes) ->
        # Parse comma-separated string
        attribute_list =
          attributes
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {:ok, attribute_list}

      _ ->
        {:error, "#{key} must be a comma-separated string or array"}
    end
  end

  defp parse_search_sort_order_param(params, key) do
    case Map.get(params, key) do
      nil ->
        {:ok, :ascending}

      "ascending" ->
        {:ok, :ascending}

      "descending" ->
        {:ok, :descending}

      value when is_atom(value) ->
        case value do
          :ascending -> {:ok, :ascending}
          :descending -> {:ok, :descending}
          _ -> {:error, "#{key} must be 'ascending' or 'descending'"}
        end

      _ ->
        {:error, "#{key} must be 'ascending' or 'descending'"}
    end
  end

  defp search_all_resources(scope, params) do
    # Search across all resource types (Users, Groups, etc.)
    with {:ok, users, user_count} <- Users.list_users_scim(scope, params),
         {:ok, groups, group_count} <- Groups.list_groups_scim(scope, params) do
      # Add resourceType to meta for each resource
      users_with_meta =
        Enum.map(users, fn user ->
          put_in(user, ["meta", "resourceType"], "User")
        end)

      groups_with_meta =
        Enum.map(groups, fn group ->
          put_in(group, ["meta", "resourceType"], "Group")
        end)

      # Combine all resources
      all_resources = users_with_meta ++ groups_with_meta
      total_count = user_count + group_count

      # Apply pagination across combined results
      # TODO: This is a simple implementation. For better performance at scale,
      # handle pagination at the database level.
      start_index = params.start_index - 1
      count = params.count

      paginated_resources =
        all_resources
        |> Enum.drop(start_index)
        |> Enum.take(count)

      {:ok, paginated_resources, total_count}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp determine_resource_type(path) do
    cond do
      String.contains?(path, "/Users/") -> :users
      String.contains?(path, "/Groups/") -> :groups
      true -> :unknown
    end
  end

  defp search_by_resource_type(:users, scope, params) do
    Users.list_users_scim(scope, params)
  end

  defp search_by_resource_type(:groups, scope, params) do
    Groups.list_groups_scim(scope, params)
  end

  defp search_by_resource_type(_unknown, _scope, _params) do
    {:error, "Unknown resource type"}
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
end
