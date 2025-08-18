defmodule ExScim.Schema.Validator.DefaultValidator do
  @moduledoc "RFC 7643 compliant SCIM schema validator."

  @behaviour ExScim.Schema.Validator.Adapter

  alias ExScim.Schema.Repository

  @impl true
  def validate_scim_schema(scim_data) do
    with {:ok, schema_uri} <- get_schema_uri(scim_data),
         {:ok, schema} <- Repository.get_schema(schema_uri),
         {:ok, validated_data} <- validate_against_schema(scim_data, schema) do
      {:ok, validated_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def validate_scim_partial(scim_data, operation_type) do
    case operation_type do
      :patch -> validate_scim_schema_partial(scim_data)
      _ -> validate_scim_schema(scim_data)
    end
  end

  defp get_schema_uri(scim_data) do
    case Map.get(scim_data, "schemas") do
      schemas when is_list(schemas) ->
        resource_schema =
          Enum.find(schemas, fn schema ->
            String.contains?(schema, "User") or
              String.contains?(schema, "Group") or
              String.contains?(schema, "schemas:core:2.0:")
          end)

        case resource_schema do
          nil -> {:error, [schemas: "must include a valid SCIM resource schema"]}
          schema_uri -> {:ok, schema_uri}
        end

      _ ->
        {:error, [schemas: "must be provided as an array"]}
    end
  end

  defp validate_against_schema(scim_data, schema) do
    errors = []

    errors =
      errors
      |> validate_required_attributes(scim_data, schema)
      |> validate_attribute_types(scim_data, schema)
      |> validate_canonical_values(scim_data, schema)
      |> validate_mutability_rules(scim_data, schema)

    case errors do
      [] -> {:ok, scim_data}
      errors -> {:error, errors}
    end
  end

  defp validate_scim_schema_partial(scim_data) do
    with {:ok, schema_uri} <- get_schema_uri_from_defaults(),
         {:ok, schema} <- Repository.get_schema(schema_uri) do
      errors = []

      errors =
        errors
        |> validate_attribute_types(scim_data, schema)
        |> validate_canonical_values(scim_data, schema)

      case errors do
        [] -> {:ok, scim_data}
        errors -> {:error, errors}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_schema_uri_from_defaults do
    {:ok, "urn:ietf:params:scim:schemas:core:2.0:User"}
  end

  defp validate_required_attributes(errors, scim_data, schema) do
    required_attrs = get_required_attributes(schema)

    Enum.reduce(required_attrs, errors, fn attr_name, acc ->
      case Map.get(scim_data, attr_name) do
        nil -> [{String.to_atom(attr_name), "is required"} | acc]
        "" -> [{String.to_atom(attr_name), "is required"} | acc]
        _ -> acc
      end
    end)
  end

  defp validate_attribute_types(errors, scim_data, schema) do
    attributes = get_in(schema, ["attributes"]) || []

    Enum.reduce(attributes, errors, fn attr, acc ->
      attr_name = attr["name"]
      attr_type = attr["type"]
      value = Map.get(scim_data, attr_name)

      if value != nil do
        validate_type(acc, attr_name, value, attr_type, attr)
      else
        acc
      end
    end)
  end

  defp validate_canonical_values(errors, scim_data, schema) do
    attributes = get_in(schema, ["attributes"]) || []

    Enum.reduce(attributes, errors, fn attr, acc ->
      validate_attr_canonical_values(acc, scim_data, attr)
    end)
  end

  defp validate_attr_canonical_values(errors, scim_data, attr) do
    attr_name = attr["name"]
    canonical_values = attr["canonicalValues"]
    value = Map.get(scim_data, attr_name)

    cond do
      value == nil ->
        errors

      attr["type"] == "complex" ->
        validate_complex_canonical_values(errors, scim_data, attr)

      canonical_values == nil ->
        errors

      value in canonical_values ->
        errors

      true ->
        [
          {String.to_atom(attr_name), "must be one of: #{Enum.join(canonical_values, ", ")}"}
          | errors
        ]
    end
  end

  defp validate_complex_canonical_values(errors, scim_data, attr) do
    attr_name = attr["name"]
    sub_attributes = attr["subAttributes"] || []
    value = Map.get(scim_data, attr_name)

    case value do
      values when is_list(values) ->
        Enum.reduce(values, errors, fn item, acc ->
          validate_complex_item_canonical_values(acc, item, sub_attributes)
        end)

      item when is_map(item) ->
        validate_complex_item_canonical_values(errors, item, sub_attributes)

      _ ->
        errors
    end
  end

  defp validate_complex_item_canonical_values(errors, item, sub_attributes) do
    Enum.reduce(sub_attributes, errors, fn sub_attr, acc ->
      sub_attr_name = sub_attr["name"]
      canonical_values = sub_attr["canonicalValues"]
      value = Map.get(item, sub_attr_name)

      cond do
        canonical_values == nil ->
          acc

        value == nil ->
          acc

        value in canonical_values ->
          acc

        true ->
          [
            {String.to_atom(sub_attr_name),
             "must be one of: #{Enum.join(canonical_values, ", ")}"}
            | acc
          ]
      end
    end)
  end

  defp get_required_attributes(schema) do
    attributes = get_in(schema, ["attributes"]) || []

    attributes
    |> Enum.filter(fn attr -> attr["required"] == true end)
    |> Enum.map(fn attr -> attr["name"] end)
  end

  defp validate_type(errors, attr_name, value, "string", _attr) do
    if is_binary(value) do
      errors
    else
      [{String.to_atom(attr_name), "must be a string"} | errors]
    end
  end

  defp validate_type(errors, attr_name, value, "boolean", _attr) do
    if is_boolean(value) do
      errors
    else
      [{String.to_atom(attr_name), "must be a boolean"} | errors]
    end
  end

  defp validate_type(errors, attr_name, value, "complex", attr) do
    multi_valued = attr["multiValued"] || false

    cond do
      multi_valued and is_list(value) ->
        Enum.reduce(value, errors, fn item, acc ->
          if is_map(item) do
            validate_complex_sub_attributes(acc, item, attr, attr_name)
          else
            [{String.to_atom(attr_name), "complex multi-valued items must be objects"} | acc]
          end
        end)

      not multi_valued and is_map(value) ->
        validate_complex_sub_attributes(errors, value, attr, attr_name)

      multi_valued ->
        [{String.to_atom(attr_name), "must be an array of objects"} | errors]

      true ->
        [{String.to_atom(attr_name), "must be an object"} | errors]
    end
  end

  defp validate_type(errors, attr_name, value, "reference", attr) do
    if is_binary(value) do
      reference_types = attr["referenceTypes"] || []

      if length(reference_types) > 0 do
        errors
      else
        [{String.to_atom(attr_name), "reference attribute missing referenceTypes"} | errors]
      end
    else
      [{String.to_atom(attr_name), "must be a string (URI reference)"} | errors]
    end
  end

  defp validate_type(errors, _attr_name, _value, _type, _attr) do
    errors
  end

  defp validate_complex_sub_attributes(errors, value, attr, parent_name) do
    sub_attributes = attr["subAttributes"] || []

    Enum.reduce(sub_attributes, errors, fn sub_attr, acc ->
      sub_attr_name = sub_attr["name"]
      sub_attr_type = sub_attr["type"]
      sub_value = Map.get(value, sub_attr_name)

      if sub_value != nil do
        validate_type(acc, "#{parent_name}.#{sub_attr_name}", sub_value, sub_attr_type, sub_attr)
      else
        acc
      end
    end)
  end

  defp validate_mutability_rules(errors, _scim_data, schema) do
    attributes = get_in(schema, ["attributes"]) || []

    Enum.reduce(attributes, errors, fn attr, acc ->
      mutability = attr["mutability"]

      case mutability do
        m when m in ["readOnly", "readWrite", "immutable", "writeOnly"] ->
          acc

        nil ->
          acc

        invalid ->
          [
            {String.to_atom("#{attr["name"]}.mutability"), "invalid mutability value: #{invalid}"}
            | acc
          ]
      end
    end)
  end
end
