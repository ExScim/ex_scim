defmodule ExScim.Operations.Bulk do
  @moduledoc "SCIM 2.0 Bulk Operations (RFC 7644 Section 3.7)."

  alias ExScim.Operations.Users
  alias ExScim.Operations.Groups
  alias ExScim.Config

  @bulk_request_schema "urn:ietf:params:scim:api:messages:2.0:BulkRequest"
  @bulk_response_schema "urn:ietf:params:scim:api:messages:2.0:BulkResponse"

  @default_max_operations 1000
  @default_max_payload_size 1_048_576

  @type bulk_operation :: %{
          method: binary(),
          bulkId: binary(),
          path: binary(),
          data: map() | nil,
          version: binary() | nil
        }

  @type bulk_response_operation :: %{
          method: binary(),
          bulkId: binary(),
          version: binary() | nil,
          location: binary() | nil,
          response: map() | nil,
          status: binary()
        }

  @doc """
  Process a bulk request with multiple operations.

  ## Parameters

    * `bulk_request` - Map containing SCIM bulk request
    * `opts` - Options including:
      * `:fail_on_errors` - Number of errors before stopping (default: 0 = continue)
      * `:max_operations` - Maximum operations allowed (default: 1000)
      * `:max_payload_size` - Maximum payload size in bytes (default: 1MB)
      * `:base_url` - Base URL for location headers

  ## Returns

    * `{:ok, bulk_response}` - Bulk response with operation results
    * `{:error, reason}` - Error if bulk request is invalid
  """
  def process_bulk_request(bulk_request, opts \\ []) do
    with {:ok, validated_request} <- validate_bulk_request(bulk_request, opts),
         {:ok, operations} <- parse_operations(validated_request["Operations"]),
         {:ok, response_operations} <- execute_operations(operations, opts) do
      response = %{
        "schemas" => [@bulk_response_schema],
        "Operations" => response_operations
      }

      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_bulk_request(bulk_request, opts) do
    max_operations = Keyword.get(opts, :max_operations, @default_max_operations)
    max_payload_size = Keyword.get(opts, :max_payload_size, @default_max_payload_size)

    cond do
      not is_map(bulk_request) ->
        {:error, "Bulk request must be a map"}

      not has_valid_schemas?(bulk_request) ->
        {:error, "Invalid or missing schemas in bulk request"}

      not Map.has_key?(bulk_request, "Operations") ->
        {:error, "Missing Operations field in bulk request"}

      not is_list(bulk_request["Operations"]) ->
        {:error, "Operations must be an array"}

      length(bulk_request["Operations"]) == 0 ->
        {:error, "Operations array cannot be empty"}

      length(bulk_request["Operations"]) > max_operations ->
        {:error, "Too many operations. Maximum allowed: #{max_operations}"}

      estimate_payload_size(bulk_request) > max_payload_size ->
        {:error, "Payload too large. Maximum allowed: #{max_payload_size} bytes"}

      true ->
        {:ok, bulk_request}
    end
  end

  defp has_valid_schemas?(%{"schemas" => schemas}) when is_list(schemas) do
    @bulk_request_schema in schemas
  end

  defp has_valid_schemas?(_), do: false

  defp estimate_payload_size(bulk_request) do
    bulk_request
    |> :erlang.term_to_binary()
    |> byte_size()
  end

  defp parse_operations(operations) do
    parsed_operations =
      operations
      |> Enum.with_index()
      |> Enum.map(fn {operation, index} -> parse_single_operation(operation, index) end)

    errors = Enum.filter(parsed_operations, &match?({:error, _}, &1))

    if length(errors) > 0 do
      error_messages = Enum.map(errors, fn {:error, msg} -> msg end)
      {:error, "Invalid operations: #{Enum.join(error_messages, ", ")}"}
    else
      operations = Enum.map(parsed_operations, fn {:ok, op} -> op end)
      {:ok, operations}
    end
  end

  defp parse_single_operation(operation, index) do
    cond do
      not is_map(operation) ->
        {:error, "Operation #{index} must be a map"}

      not Map.has_key?(operation, "method") ->
        {:error, "Operation #{index} missing required 'method' field"}

      not Map.has_key?(operation, "bulkId") ->
        {:error, "Operation #{index} missing required 'bulkId' field"}

      not is_binary(operation["method"]) ->
        {:error, "Operation #{index} 'method' must be a string"}

      not is_binary(operation["bulkId"]) ->
        {:error, "Operation #{index} 'bulkId' must be a string"}

      operation["method"] not in ["POST", "PUT", "PATCH", "DELETE"] ->
        {:error, "Operation #{index} has invalid method: #{operation["method"]}"}

      true ->
        {:ok,
         %{
           method: operation["method"],
           bulk_id: operation["bulkId"],
           path: operation["path"],
           data: operation["data"],
           version: operation["version"]
         }}
    end
  end

  defp execute_operations(operations, opts) do
    fail_on_errors = Keyword.get(opts, :fail_on_errors, 0)
    base_url = Keyword.get(opts, :base_url, Config.base_url())

    {response_operations, _error_count} =
      Enum.reduce(operations, {[], 0}, fn operation, {acc, error_count} ->
        if fail_on_errors > 0 and error_count >= fail_on_errors do
          # Stop processing if we've hit the error limit
          {acc, error_count}
        else
          result = execute_single_operation(operation, base_url)

          new_error_count =
            if result["status"] != "200" and result["status"] != "201",
              do: error_count + 1,
              else: error_count

          {[result | acc], new_error_count}
        end
      end)

    {:ok, Enum.reverse(response_operations)}
  end

  defp execute_single_operation(operation, base_url) do
    case operation.method do
      "POST" -> handle_post_operation(operation, base_url)
      "PUT" -> handle_put_operation(operation, base_url)
      "PATCH" -> handle_patch_operation(operation, base_url)
      "DELETE" -> handle_delete_operation(operation, base_url)
    end
  rescue
    error ->
      %{
        "method" => operation.method,
        "bulkId" => operation.bulk_id,
        "status" => "500",
        "response" => %{
          "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
          "detail" => "Internal server error: #{Exception.message(error)}",
          "status" => "500"
        }
      }
  end

  defp handle_post_operation(operation, base_url) do
    {resource_type, _resource_id} = parse_path(operation.path)

    case resource_type do
      :users ->
        case Users.create_user_from_scim(operation.data) do
          {:ok, user} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "201",
              "location" => "#{base_url}/scim/v2/Users/#{user["id"]}",
              "version" => get_in(user, ["meta", "etag"]),
              "response" => user
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :groups ->
        case Groups.create_group_from_scim(operation.data) do
          {:ok, group} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "201",
              "location" => "#{base_url}/scim/v2/Groups/#{group["id"]}",
              "version" => get_in(group, ["meta", "etag"]),
              "response" => group
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :unknown ->
        %{
          method: operation.method,
          bulkId: operation.bulk_id,
          status: "400",
          response: format_error_response("Invalid resource path", "400")
        }
    end
  end

  defp handle_put_operation(operation, base_url) do
    {resource_type, resource_id} = parse_path(operation.path)

    case resource_type do
      :users ->
        case Users.replace_user_from_scim(resource_id, operation.data) do
          {:ok, user} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "200",
              "location" => "#{base_url}/scim/v2/Users/#{user["id"]}",
              "version" => get_in(user, ["meta", "etag"]),
              "response" => user
            }

          {:error, :not_found} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "404",
              "response" => format_error_response("Resource not found", "404")
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :groups ->
        case Groups.replace_group_from_scim(resource_id, operation.data) do
          {:ok, group} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "200",
              "location" => "#{base_url}/scim/v2/Groups/#{group["id"]}",
              "version" => get_in(group, ["meta", "etag"]),
              "response" => group
            }

          {:error, :not_found} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "404",
              "response" => format_error_response("Resource not found", "404")
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :unknown ->
        %{
          method: operation.method,
          bulkId: operation.bulk_id,
          status: "400",
          response: format_error_response("Invalid resource path", "400")
        }
    end
  end

  defp handle_patch_operation(operation, base_url) do
    {resource_type, resource_id} = parse_path(operation.path)

    case resource_type do
      :users ->
        case Users.patch_user_from_scim(resource_id, operation.data) do
          {:ok, user} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "200",
              "location" => "#{base_url}/scim/v2/Users/#{user["id"]}",
              "version" => get_in(user, ["meta", "etag"]),
              "response" => user
            }

          {:error, :not_found} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "404",
              "response" => format_error_response("Resource not found", "404")
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :groups ->
        case Groups.patch_group_from_scim(resource_id, operation.data) do
          {:ok, group} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "200",
              "location" => "#{base_url}/scim/v2/Groups/#{group["id"]}",
              "version" => get_in(group, ["meta", "etag"]),
              "response" => group
            }

          {:error, :not_found} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "404",
              "response" => format_error_response("Resource not found", "404")
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :unknown ->
        %{
          method: operation.method,
          bulkId: operation.bulk_id,
          status: "400",
          response: format_error_response("Invalid resource path", "400")
        }
    end
  end

  defp handle_delete_operation(operation, _base_url) do
    {resource_type, resource_id} = parse_path(operation.path)

    case resource_type do
      :users ->
        case Users.delete_user(resource_id) do
          :ok ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "204"
            }

          {:error, :not_found} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "404",
              "response" => format_error_response("Resource not found", "404")
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :groups ->
        case Groups.delete_group(resource_id) do
          :ok ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "204"
            }

          {:error, :not_found} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "404",
              "response" => format_error_response("Resource not found", "404")
            }

          {:error, reason} ->
            %{
              "method" => operation.method,
              "bulkId" => operation.bulk_id,
              "status" => "400",
              "response" => format_error_response(reason, "400")
            }
        end

      :unknown ->
        %{
          method: operation.method,
          bulkId: operation.bulk_id,
          status: "400",
          response: format_error_response("Invalid resource path", "400")
        }
    end
  end

  defp parse_path(nil), do: {:unknown, nil}

  defp parse_path(path) when is_binary(path) do
    case String.split(path, "/", trim: true) do
      ["Users", resource_id] -> {:users, resource_id}
      ["Groups", resource_id] -> {:groups, resource_id}
      ["Users"] -> {:users, nil}
      ["Groups"] -> {:groups, nil}
      _ -> {:unknown, nil}
    end
  end

  defp parse_path(_), do: {:unknown, nil}

  defp format_error_response(reason, status) when is_binary(reason) do
    %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "detail" => reason,
      "status" => status
    }
  end

  defp format_error_response(reason, status) when is_list(reason) do
    detail =
      Enum.map(reason, fn
        {field, message} -> "#{field}: #{message}"
        message when is_binary(message) -> message
        error -> inspect(error)
      end)
      |> Enum.join(", ")

    %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "detail" => detail,
      "status" => status
    }
  end

  defp format_error_response(reason, status) do
    %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "detail" => inspect(reason),
      "status" => status
    }
  end
end
