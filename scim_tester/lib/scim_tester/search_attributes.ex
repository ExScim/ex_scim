defmodule ScimTester.SearchAttributes do
  @moduledoc """
  Computes the grouped attribute options offered in the search composer.

  Options are derived from the provider's fetched schemas when available, and
  fall back to a curated static list otherwise. Also owns the SCIM core/extension
  schema identifiers used across the app.
  """

  @user_schema_id "urn:ietf:params:scim:schemas:core:2.0:User"
  @group_schema_id "urn:ietf:params:scim:schemas:core:2.0:Group"
  @enterprise_user_schema_id "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

  @common_attributes [
    {"id", "id"},
    {"externalId", "externalId"},
    {"meta.created", "meta.created"},
    {"meta.lastModified", "meta.lastModified"}
  ]

  @fallback_user_attributes [
    {"userName", "userName"},
    {"displayName", "displayName"},
    {"name.givenName", "name.givenName"},
    {"name.familyName", "name.familyName"},
    {"emails.value", "emails.value"},
    {"active", "active"},
    {"title", "title"},
    {"userType", "userType"}
  ]

  @fallback_group_attributes [
    {"displayName", "displayName"},
    {"members.value", "members.value"},
    {"members.display", "members.display"}
  ]

  def user_schema_id, do: @user_schema_id
  def group_schema_id, do: @group_schema_id
  def enterprise_user_schema_id, do: @enterprise_user_schema_id

  @doc """
  Returns the default schema set enabled before any schemas are fetched.
  """
  def default_enabled_schemas, do: MapSet.new([@user_schema_id, @group_schema_id])

  @doc """
  Returns grouped attribute options as a list of `{group_label, [{value, label}]}`
  for the given `resource_type`, fetched `schemas` map (or `nil`), and the set of
  `enabled_schemas`.
  """
  def options(resource_type, schemas, enabled_schemas)

  def options("Groups", nil, _enabled_schemas) do
    [{"Group", @fallback_group_attributes ++ @common_attributes}]
  end

  def options(_resource_type, nil, _enabled_schemas) do
    [{"User", @fallback_user_attributes ++ @common_attributes}]
  end

  def options("Groups", schemas, _enabled_schemas) do
    group =
      case Map.get(schemas, @group_schema_id) do
        nil -> [{"Group", @fallback_group_attributes}]
        schema -> [{"Group", schema_to_attributes(schema, nil)}]
      end

    group ++ [{"Common", @common_attributes}]
  end

  def options("Users", schemas, enabled_schemas) do
    groups =
      if MapSet.member?(enabled_schemas, @user_schema_id) do
        case Map.get(schemas, @user_schema_id) do
          nil -> [{"User", @fallback_user_attributes}]
          schema -> [{"User", schema_to_attributes(schema, nil)}]
        end
      else
        []
      end

    groups =
      if MapSet.member?(enabled_schemas, @enterprise_user_schema_id) do
        case Map.get(schemas, @enterprise_user_schema_id) do
          nil ->
            groups

          schema ->
            groups ++
              [{"Enterprise User", schema_to_attributes(schema, @enterprise_user_schema_id)}]
        end
      else
        groups
      end

    groups ++ [{"Common", @common_attributes}]
  end

  @doc """
  Returns the default attribute value for a new filter row, falling back to a
  sensible per-resource-type default when no options are available.
  """
  def default_attribute(resource_type, schemas, enabled_schemas) do
    case options(resource_type, schemas, enabled_schemas) do
      [{_group, [{value, _label} | _]} | _] -> value
      _ -> if resource_type == "Groups", do: "displayName", else: "userName"
    end
  end

  defp schema_to_attributes(schema, uri_prefix) do
    schema
    |> Map.get("attributes", [])
    |> Enum.flat_map(fn attr ->
      name = Map.get(attr, "name", "")
      type = Map.get(attr, "type", "")

      if type == "complex" do
        attr
        |> Map.get("subAttributes", [])
        |> Enum.reject(fn sub -> Map.get(sub, "name") == "$ref" end)
        |> Enum.map(fn sub ->
          path = "#{name}.#{Map.get(sub, "name", "")}"
          prefixed = if uri_prefix, do: "#{uri_prefix}:#{path}", else: path
          {prefixed, prefixed}
        end)
      else
        prefixed = if uri_prefix, do: "#{uri_prefix}:#{name}", else: name
        [{prefixed, prefixed}]
      end
    end)
    |> Enum.sort_by(fn {_value, label} -> label end)
  end
end
