defmodule ExScim.SCIMComplianceHelpers do
  @moduledoc """
  Helper functions for validating SCIM RFC 7644 compliance.
  """

  import ExUnit.Assertions

  @doc """
  Assert that a response conforms to SCIM format with required schema.
  """
  def assert_scim_response(response, expected_schema) do
    assert is_map(response), "Response must be a map"
    assert Map.has_key?(response, "schemas"), "Response must include schemas"

    schemas = response["schemas"]
    assert is_list(schemas), "Schemas must be an array"
    assert expected_schema in schemas, "Response must include expected schema: #{expected_schema}"

    response
  end

  @doc """
  Assert that an error response conforms to SCIM error format.
  """
  def assert_scim_error(response, expected_scim_type, expected_status) do
    error_schema = "urn:ietf:params:scim:api:messages:2.0:Error"
    assert_scim_response(response, error_schema)

    assert Map.has_key?(response, "scimType"), "Error must include scimType"

    assert response["scimType"] == expected_scim_type,
           "Expected scimType #{expected_scim_type}, got #{response["scimType"]}"

    assert Map.has_key?(response, "detail"), "Error must include detail"
    assert is_binary(response["detail"]), "Detail must be a string"

    assert Map.has_key?(response, "status"), "Error must include status"

    assert response["status"] == to_string(expected_status),
           "Expected status #{expected_status}, got #{response["status"]}"

    response
  end

  @doc """
  Assert that a list response conforms to SCIM ListResponse format.
  """
  def assert_scim_list_response(response, expected_resources, expected_total) do
    list_schema = "urn:ietf:params:scim:api:messages:2.0:ListResponse"
    assert_scim_response(response, list_schema)

    assert Map.has_key?(response, "Resources"), "List response must include Resources"
    assert Map.has_key?(response, "totalResults"), "List response must include totalResults"
    assert Map.has_key?(response, "startIndex"), "List response must include startIndex"
    assert Map.has_key?(response, "itemsPerPage"), "List response must include itemsPerPage"

    resources = response["Resources"]
    assert is_list(resources), "Resources must be an array"

    assert length(resources) == expected_resources,
           "Expected #{expected_resources} resources, got #{length(resources)}"

    assert response["totalResults"] == expected_total,
           "Expected totalResults #{expected_total}, got #{response["totalResults"]}"

    response
  end

  @doc """
  Assert that a user resource has required SCIM user attributes.
  """
  def assert_scim_user_resource(user) do
    user_schema = "urn:ietf:params:scim:schemas:core:2.0:User"
    assert_scim_response(user, user_schema)

    # Required attributes
    assert Map.has_key?(user, "id"), "User must have id"
    assert Map.has_key?(user, "userName"), "User must have userName"
    assert Map.has_key?(user, "meta"), "User must have meta"

    # Validate meta object
    meta = user["meta"]
    assert is_map(meta), "Meta must be an object"
    assert Map.has_key?(meta, "resourceType"), "Meta must include resourceType"
    assert meta["resourceType"] == "User", "ResourceType must be User"
    assert Map.has_key?(meta, "created"), "Meta must include created timestamp"
    assert Map.has_key?(meta, "lastModified"), "Meta must include lastModified timestamp"

    # Validate timestamps are ISO 8601 format
    assert_iso8601_timestamp(meta["created"])
    assert_iso8601_timestamp(meta["lastModified"])

    user
  end

  @doc """
  Assert that a timestamp is in valid ISO 8601 format.
  """
  def assert_iso8601_timestamp(timestamp) do
    assert is_binary(timestamp), "Timestamp must be a string"

    case DateTime.from_iso8601(timestamp) do
      {:ok, _datetime, _offset} ->
        :ok

      {:error, reason} ->
        flunk("Invalid ISO 8601 timestamp '#{timestamp}': #{reason}")
    end
  end

  @doc """
  Assert that multi-valued attributes follow SCIM format.
  """
  def assert_scim_multi_valued_attribute(attribute, required_fields \\ []) do
    assert is_list(attribute), "Multi-valued attribute must be an array"

    for item <- attribute do
      assert is_map(item), "Multi-valued attribute item must be an object"
      assert Map.has_key?(item, "value"), "Multi-valued item must have value"

      for field <- required_fields do
        assert Map.has_key?(item, field), "Multi-valued item must have #{field}"
      end

      # If primary is present, it must be boolean
      if Map.has_key?(item, "primary") do
        assert is_boolean(item["primary"]), "Primary must be boolean"
      end

      # If type is present, it must be string
      if Map.has_key?(item, "type") do
        assert is_binary(item["type"]), "Type must be string"
      end
    end
  end

  @doc """
  Assert that PATCH operations follow SCIM format.
  """
  def assert_scim_patch_operations(operations) do
    assert Map.has_key?(operations, "Operations"), "PATCH must include Operations"

    ops_list = operations["Operations"]
    assert is_list(ops_list), "Operations must be an array"
    assert length(ops_list) > 0, "Operations array cannot be empty"

    for operation <- ops_list do
      assert is_map(operation), "Operation must be an object"
      assert Map.has_key?(operation, "op"), "Operation must include op"

      op = operation["op"]

      assert op in ["add", "remove", "replace"],
             "Op must be one of: add, remove, replace. Got: #{op}"

      # Path is optional for add/replace with no path (applies to resource root)
      if Map.has_key?(operation, "path") and not is_nil(operation["path"]) do
        assert is_binary(operation["path"]), "Path must be a string"
      end

      # Value is required for add/replace operations
      if op in ["add", "replace"] do
        assert Map.has_key?(operation, "value"), "#{op} operation must include value"
      end
    end
  end

  @doc """
  Validate SCIM filter expressions syntax.
  """
  def assert_valid_scim_filter(filter_expression) do
    assert is_binary(filter_expression), "Filter must be a string"
    assert String.trim(filter_expression) != "", "Filter cannot be empty"

    # Basic syntax validation - could be expanded with proper parser
    forbidden_patterns = [
      # Ending with logical operator
      ~r/\s(and|or)\s*$/i,
      # Starting with logical operator
      ~r/^(and|or)\s/i,
      # Empty parentheses
      ~r/\(\s*\)/,
      # Ending with comparison operator
      ~r/\s(eq|ne|co|sw|ew|pr|gt|ge|lt|le)\s*$/i
    ]

    for pattern <- forbidden_patterns do
      refute Regex.match?(pattern, filter_expression),
             "Invalid filter syntax: #{filter_expression}"
    end
  end

  @doc """
  Validate SCIM attribute path expressions.
  """
  def assert_valid_scim_path(path_expression) do
    assert is_binary(path_expression), "Path must be a string"
    assert String.trim(path_expression) != "", "Path cannot be empty"

    # Basic path validation
    refute String.contains?(path_expression, ".."), "Path cannot contain '..'"
    refute String.starts_with?(path_expression, "."), "Path cannot start with '.'"
    refute String.ends_with?(path_expression, "."), "Path cannot end with '.'"
  end

  @doc """
  Assert that pagination parameters are valid.
  """
  def assert_valid_pagination(start_index, count) do
    if start_index do
      assert is_integer(start_index), "startIndex must be integer"
      assert start_index >= 1, "startIndex must be >= 1"
    end

    if count do
      assert is_integer(count), "count must be integer"
      assert count >= 0, "count must be >= 0"
    end
  end

  @doc """
  Assert that sorting parameters are valid.
  """
  def assert_valid_sorting(sort_by, sort_order) do
    if sort_by do
      assert is_binary(sort_by), "sortBy must be string"
      assert String.trim(sort_by) != "", "sortBy cannot be empty"
    end

    if sort_order do
      assert sort_order in ["ascending", "descending"],
             "sortOrder must be 'ascending' or 'descending'"
    end
  end

  @doc """
  Create a mock SCIM context for testing.
  """
  def mock_scim_context(opts \\ []) do
    %{
      base_url: Keyword.get(opts, :base_url, "http://localhost:4000"),
      resource_endpoint: Keyword.get(opts, :resource_endpoint, "/scim/v2/Users"),
      auth_header: Keyword.get(opts, :auth_header, "Bearer test-token"),
      content_type: "application/scim+json"
    }
  end

  @doc """
  Generate test data for common SCIM compliance scenarios.
  """
  def compliance_test_scenarios do
    %{
      create_user: %{
        valid_payload: ExScim.TestFixtures.valid_scim_user_attrs(),
        invalid_payload: ExScim.TestFixtures.invalid_scim_user_attrs(),
        expected_status: 201,
        required_headers: ["Location", "ETag"]
      },
      get_user: %{
        expected_status: 200,
        required_headers: ["ETag"],
        not_found_status: 404
      },
      update_user: %{
        valid_payload: ExScim.TestFixtures.valid_scim_user_attrs(),
        expected_status: 200,
        required_headers: ["ETag"],
        conflict_status: 409
      },
      patch_user: %{
        valid_payload: ExScim.TestFixtures.valid_patch_operations(),
        invalid_payload: ExScim.TestFixtures.malformed_patch_operations(),
        expected_status: 200,
        required_headers: ["ETag"]
      },
      delete_user: %{
        expected_status: 204,
        not_found_status: 404
      },
      list_users: %{
        expected_status: 200,
        required_schema: "urn:ietf:params:scim:api:messages:2.0:ListResponse"
      }
    }
  end
end
