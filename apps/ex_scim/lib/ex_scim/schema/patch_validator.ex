defmodule ExScim.Schema.PatchValidator do
  @moduledoc false
  # Checks PatchOp paths and values against a resource type's schemas and
  # rewrites attribute names to the schema's spelling.

  alias ExScim.Config
  alias ExScim.Parser.Path
  alias ExScim.Schema.Repository

  @common_attributes [
    %{"name" => "id", "mutability" => "readOnly"},
    %{"name" => "externalId", "type" => "string", "mutability" => "readWrite"},
    %{"name" => "meta", "type" => "complex", "mutability" => "readOnly"}
  ]

  @doc """
  Validates `patch_ops` against the schemas of `resource_type` (`"User"` or
  `"Group"`) and returns them with attribute names in the schema's spelling.

  Unknown attributes return `:invalid_path`. A path to a `readOnly` attribute,
  or replacing or removing an `immutable` one, returns `:mutability`.
  Read-only values inside `value` are checked by `validate_changes/3`.
  Malformed operations are passed through for the patcher to report.
  """
  @spec validate(map(), String.t()) ::
          {:ok, map()} | {:error, {:invalid_patch, ExScim.Error.scim_type(), String.t()}}
  def validate(%{"Operations" => operations} = patch_ops, resource_type)
      when is_list(operations) do
    case schemas(resource_type) do
      nil ->
        {:ok, patch_ops}

      schemas ->
        map_operations(patch_ops, fn operation ->
          with {:ok, operation, targets} <- resolve(operation, schemas),
               :ok <- check_mutability(operation, targets) do
            {:ok, operation}
          end
        end)
    end
  end

  def validate(patch_ops, _resource_type), do: {:ok, patch_ops}

  @doc """
  Validates `patch_ops` against `resource`, the resource's current SCIM
  representation.

  Read-only values inside `value`, and immutable ones in a `replace`, must
  equal the current value and are then dropped. An `add` to an immutable
  attribute that already has a different value returns `:mutability`.
  Paths with a filter aren't checked.
  """
  @spec validate_changes(map(), map(), String.t()) ::
          {:ok, map()} | {:error, {:invalid_patch, ExScim.Error.scim_type(), String.t()}}
  def validate_changes(%{"Operations" => operations} = patch_ops, resource, resource_type)
      when is_list(operations) do
    case schemas(resource_type) do
      nil ->
        {:ok, patch_ops}

      schemas ->
        map_operations(patch_ops, fn operation ->
          case resolve(operation, schemas) do
            {:ok, _operation, targets} -> check_changes(operation, targets, resource)
            _ -> {:ok, operation}
          end
        end)
    end
  end

  def validate_changes(patch_ops, _resource, _resource_type), do: {:ok, patch_ops}

  defp map_operations(%{"Operations" => operations} = patch_ops, fun) do
    operations
    |> Enum.reduce_while({:ok, []}, fn operation, {:ok, acc} ->
      case fun.(operation) do
        {:ok, operation} -> {:cont, {:ok, [operation | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, operations} -> {:ok, %{patch_ops | "Operations" => Enum.reverse(operations)}}
      error -> error
    end
  end

  defp schemas(resource_type) do
    with %{} = type <- Enum.find(Config.resource_types(), &(&1.id == resource_type)),
         {:ok, core} <- Repository.get_schema(type.schema) do
      extensions =
        for extension <- Map.get(type, :schema_extensions, []),
            {:ok, schema} <- [Repository.get_schema(extension.schema)],
            do: schema

      %{core: core, extensions: extensions}
    else
      _ -> nil
    end
  end

  defp check_mutability(%{"op" => op}, targets) do
    op = String.downcase(op)

    Enum.find_value(targets, :ok, fn
      %{attr: %{"mutability" => "readOnly", "name" => name}, value_keys: nil} ->
        mutability("#{name} is read-only")

      %{attr: %{"mutability" => "readOnly", "name" => name}, keys: nil} ->
        mutability("#{name} is read-only")

      %{attr: %{"mutability" => "immutable", "name" => name}, value_keys: nil}
      when op in ["replace", "remove"] ->
        mutability("#{name} is immutable")

      _ ->
        nil
    end)
  end

  defp check_mutability(_operation, _targets), do: :ok

  defp check_changes(%{"op" => op} = operation, targets, resource) do
    op = String.downcase(op)

    targets
    |> Enum.reduce_while({:ok, []}, fn target, {:ok, drops} ->
      case check_change(op, operation, target, resource) do
        :ok -> {:cont, {:ok, drops}}
        {:drop, value_keys} -> {:cont, {:ok, [value_keys | drops]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, drops} -> {:ok, Enum.reduce(drops, operation, &drop_value(&2, &1))}
      error -> error
    end
  end

  defp check_change(op, operation, %{attr: attr, keys: keys} = target, resource)
       when is_list(keys) do
    given = given_value(operation, target)
    current = lookup_in(resource, keys)
    name = Enum.join(keys, ".")

    case {attr["mutability"], op, target.value_keys} do
      {"readOnly", _op, value_keys} when is_list(value_keys) ->
        if given == current, do: {:drop, value_keys}, else: mutability("#{name} is read-only")

      {"immutable", "replace", value_keys} when is_list(value_keys) ->
        if given == current, do: {:drop, value_keys}, else: mutability("#{name} is immutable")

      {"immutable", "add", _value_keys} ->
        if empty?(current) or given == current,
          do: :ok,
          else: mutability("#{name} is immutable and already set")

      _ ->
        :ok
    end
  end

  defp check_change(_op, _operation, _target, _resource), do: :ok

  defp given_value(operation, %{value_keys: nil}), do: operation["value"]

  defp given_value(operation, %{value_keys: value_keys}),
    do: get_in(operation, ["value" | value_keys])

  defp drop_value(operation, value_keys) do
    {_, operation} = pop_in(operation, ["value" | value_keys])
    operation
  end

  # Resolution returns the operation in schema spelling and its targets, one
  # per attribute it writes: `keys` is the location in the SCIM resource (nil
  # behind a filter), `value_keys` the location inside `value` (nil for the
  # path's own target).

  defp resolve(%{"op" => op} = operation, schemas) when is_binary(op) do
    case Map.get(operation, "path") do
      path when is_binary(path) -> resolve_path(operation, path, schemas)
      nil -> resolve_attributes(operation, schemas)
      _ -> {:ok, operation, []}
    end
  end

  defp resolve(operation, _schemas), do: {:ok, operation, []}

  defp resolve_path(operation, path, schemas) do
    with {:ok, parsed} <- parse(path),
         {:ok, schema} <- find_schema(parsed[:schema], schemas, path),
         {:ok, attr_name, sub_name} <- split(parsed.attribute, parsed[:sub], path),
         {:ok, attr} <- find_attribute(schema, attr_name, schemas, path),
         {:ok, sub} <- find_sub_attribute(attr, sub_name, path) do
      filter = parsed[:filter]
      target = sub || attr

      canonical =
        if(parsed[:schema], do: schema["id"] <> ":", else: "") <>
          attr["name"] <>
          if(filter, do: "[#{filter}]", else: "") <>
          if(sub, do: "." <> sub["name"], else: "")

      keys =
        unless filter do
          extension_key(parsed[:schema], schema, schemas) ++
            [attr["name"]] ++ if(sub, do: [sub["name"]], else: [])
        end

      with {:ok, value, value_targets} <- resolve_value(operation["value"], target, keys, []) do
        operation =
          operation
          |> Map.put("path", canonical)
          |> put_value(value)

        {:ok, operation, [%{keys: keys, attr: target, value_keys: nil} | value_targets]}
      end
    end
  end

  defp resolve_attributes(%{"value" => value} = operation, schemas) when is_map(value) do
    value
    |> Enum.reduce_while({:ok, %{}, []}, fn {key, inner}, {:ok, acc, targets} ->
      case resolve_attribute(key, inner, schemas) do
        {:ok, name, inner, new_targets} ->
          {:cont, {:ok, Map.put(acc, name, inner), targets ++ new_targets}}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, value, targets} -> {:ok, Map.put(operation, "value", value), targets}
      error -> error
    end
  end

  defp resolve_attributes(operation, _schemas), do: {:ok, operation, []}

  defp resolve_attribute(key, value, schemas) do
    case find_by_name(schemas.extensions, key, "id") do
      nil ->
        with {:ok, attr} <- find_attribute(schemas.core, key, schemas, key),
             keys = [attr["name"]],
             {:ok, value, targets} <- resolve_value(value, attr, keys, keys) do
          {:ok, attr["name"], value, [%{keys: keys, attr: attr, value_keys: keys} | targets]}
        end

      extension when is_map(value) ->
        resolve_extension(extension, value, schemas)

      extension ->
        invalid_path("#{extension["id"]} must be an object")
    end
  end

  defp resolve_extension(extension, value, schemas) do
    id = extension["id"]

    value
    |> Enum.reduce_while({:ok, %{}, []}, fn {key, inner}, {:ok, acc, targets} ->
      with {:ok, attr} <- find_attribute(extension, key, schemas, "#{id}:#{key}"),
           keys = [id, attr["name"]],
           {:ok, inner, value_targets} <- resolve_value(inner, attr, keys, keys) do
        target = %{keys: keys, attr: attr, value_keys: keys}
        {:cont, {:ok, Map.put(acc, attr["name"], inner), targets ++ [target | value_targets]}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, value, targets} -> {:ok, id, value, targets}
      error -> error
    end
  end

  # Keys of a single-valued complex value are sub-attributes the operation
  # writes. Elements of multi-valued attributes only get schema spelling.
  defp resolve_value(value, %{"type" => "complex"} = attr, keys, value_keys)
       when is_map(value) do
    if attr["multiValued"] do
      {:ok, rename_known(value, attr), []}
    else
      value
      |> Enum.reduce_while({:ok, %{}, []}, fn {key, inner}, {:ok, acc, targets} ->
        case find_by_name(attr["subAttributes"] || [], key) do
          nil ->
            {:halt, invalid_path("Unknown attribute #{attr["name"]}.#{key}")}

          sub ->
            target = %{
              keys: keys && keys ++ [sub["name"]],
              attr: sub,
              value_keys: value_keys ++ [sub["name"]]
            }

            {:cont, {:ok, Map.put(acc, sub["name"], inner), [target | targets]}}
        end
      end)
    end
  end

  defp resolve_value(values, %{"type" => "complex"} = attr, _keys, _value_keys)
       when is_list(values) do
    {:ok, Enum.map(values, &rename_known(&1, attr)), []}
  end

  defp resolve_value(value, _attr, _keys, _value_keys), do: {:ok, value, []}

  defp rename_known(element, attr) when is_map(element) do
    Map.new(element, fn {key, value} ->
      case find_by_name(attr["subAttributes"] || [], key) do
        nil -> {key, value}
        sub -> {sub["name"], value}
      end
    end)
  end

  defp rename_known(element, _attr), do: element

  defp parse(path) do
    case Path.path(path) do
      {:ok, [parsed], "", _, _, _} -> {:ok, parsed}
      _ -> invalid_path("Invalid path: #{inspect(path)}")
    end
  end

  defp find_schema(nil, schemas, _path), do: {:ok, schemas.core}

  defp find_schema(uri, schemas, path) do
    case find_by_name([schemas.core | schemas.extensions], uri, "id") do
      nil -> invalid_path("Unknown schema in path: #{inspect(path)}")
      schema -> {:ok, schema}
    end
  end

  defp split(attribute, sub, path) do
    case String.split(attribute, ".") do
      [attr] -> {:ok, attr, sub}
      [attr, dotted] when is_nil(sub) -> {:ok, attr, dotted}
      _ -> invalid_path("Invalid path: #{inspect(path)}")
    end
  end

  defp find_attribute(schema, name, schemas, path) do
    attributes =
      if schema == schemas.core,
        do: schema["attributes"] ++ @common_attributes,
        else: schema["attributes"]

    case find_by_name(attributes, name) do
      nil -> invalid_path("Unknown attribute: #{inspect(path)}")
      attr -> {:ok, attr}
    end
  end

  defp find_sub_attribute(_attr, nil, _path), do: {:ok, nil}

  defp find_sub_attribute(attr, name, path) do
    case find_by_name(attr["subAttributes"] || [], name) do
      nil -> invalid_path("Unknown attribute: #{inspect(path)}")
      sub -> {:ok, sub}
    end
  end

  defp extension_key(nil, _schema, _schemas), do: []
  defp extension_key(_uri, schema, schemas) when schema == schemas.core, do: []
  defp extension_key(_uri, schema, _schemas), do: [schema["id"]]

  # SCIM attribute and schema names are case-insensitive (RFC 7643 section 2.1).
  defp find_by_name(items, name, field \\ "name") do
    name = String.downcase(name)
    Enum.find(items, &(String.downcase(&1[field] || "") == name))
  end

  defp lookup_in(value, []), do: value

  defp lookup_in(resource, [key | rest]) when is_map(resource) do
    key = String.downcase(key)

    resource
    |> Enum.find_value(fn {k, v} -> if is_binary(k) and String.downcase(k) == key, do: {v} end)
    |> case do
      {value} -> lookup_in(value, rest)
      nil -> nil
    end
  end

  defp lookup_in(_value, _keys), do: nil

  defp empty?(value), do: value in [nil, "", [], %{}]

  defp put_value(operation, value) do
    if Map.has_key?(operation, "value"), do: Map.put(operation, "value", value), else: operation
  end

  defp invalid_path(message), do: {:error, {:invalid_patch, :invalid_path, message}}
  defp mutability(message), do: {:error, {:invalid_patch, :mutability, message}}
end
