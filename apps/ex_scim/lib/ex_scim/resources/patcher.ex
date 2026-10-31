defmodule ExScim.Resources.Patcher do
  @moduledoc false
  # Shared implementation of `ExScim.Users.Patcher` and `ExScim.Groups.Patcher`.

  require Logger

  alias ExScim.Parser.Filter
  alias ExScim.Parser.Path
  alias ExScim.Resources.PatchError

  @spec patch(map() | struct(), map(), [String.t()], String.t()) ::
          {:ok, map() | struct()}
          | {:error, {:invalid_patch, ExScim.Error.scim_type(), String.t()}}
  def patch(resource, %{"Operations" => operations}, multi_valued, core_schema)
      when is_list(operations) do
    if length(operations) == 0 do
      invalid_patch("Operations array cannot be empty")
    else
      ctx = %{
        multi_valued: Enum.map(multi_valued, &String.downcase/1),
        core_schema: core_schema,
        domain?: domain_data?(resource)
      }

      if ctx.domain? do
        Logger.warning(
          "Patching structs or atom-keyed maps is deprecated and will be removed in 0.6.0. " <>
            "Patch the SCIM representation instead."
        )
      end

      try do
        updated =
          Enum.reduce(operations, resource, fn op, acc ->
            apply_op(acc, op, ctx)
          end)

        {:ok, if(ctx.domain?, do: updated, else: list_extension_schemas(updated))}
      rescue
        e in PatchError -> {:error, {:invalid_patch, e.scim_type, e.message}}
      end
    end
  end

  def patch(_resource, patch_ops, _multi_valued, _core_schema) do
    cond do
      not is_map(patch_ops) ->
        invalid_patch("Patch operations must be a map")

      not Map.has_key?(patch_ops, "Operations") ->
        invalid_patch("Missing required Operations field")

      not is_list(patch_ops["Operations"]) ->
        invalid_patch("Operations must be an array")

      true ->
        invalid_patch("Invalid patch operations format")
    end
  end

  defp invalid_patch(message), do: {:error, {:invalid_patch, :invalid_syntax, message}}

  defp domain_data?(resource) do
    is_struct(resource) or Enum.any?(Map.keys(resource), &is_atom/1)
  end

  # RFC 7643 section 3: `schemas` lists every extension the resource uses.
  defp list_extension_schemas(%{"schemas" => schemas} = resource) when is_list(schemas) do
    listed = Enum.map(schemas, &String.downcase/1)

    missing =
      for {key, value} <- resource,
          is_binary(key),
          String.starts_with?(String.downcase(key), "urn:"),
          value not in [nil, %{}],
          String.downcase(key) not in listed,
          do: key

    Map.put(resource, "schemas", schemas ++ missing)
  end

  defp list_extension_schemas(resource), do: resource

  defp apply_op(resource, %{"op" => op} = operation, ctx) when is_binary(op) do
    case String.downcase(op) do
      "add" -> apply_add(resource, operation, ctx)
      "replace" -> apply_replace(resource, operation, ctx)
      "remove" -> apply_remove(resource, operation, ctx)
      other -> raise PatchError, "Unsupported op: #{inspect(other)}"
    end
  end

  defp apply_op(_resource, operation, _ctx) do
    raise PatchError, "Invalid operation: #{inspect(operation)} - missing or invalid 'op' field"
  end

  defp apply_add(resource, %{"value" => value} = operation, ctx) do
    apply_set(resource, operation["path"], value, :add, ctx)
  end

  defp apply_add(_resource, operation, _ctx) do
    raise PatchError,
      message: "Add operation missing required 'value' field: #{inspect(operation)}",
      scim_type: :invalid_value
  end

  defp apply_replace(resource, %{"value" => value} = operation, ctx) do
    apply_set(resource, operation["path"], value, :replace, ctx)
  end

  defp apply_replace(_resource, operation, _ctx) do
    raise PatchError,
      message: "Replace operation missing required 'value' field: #{inspect(operation)}",
      scim_type: :invalid_value
  end

  defp apply_set(resource, nil, value, mode, ctx) when is_map(value) do
    merge_attributes(resource, value, mode, ctx)
  end

  defp apply_set(_resource, nil, value, _mode, _ctx) do
    raise PatchError,
      message: "Operation without a path requires an object value, got: #{inspect(value)}",
      scim_type: :invalid_value
  end

  defp apply_set(resource, path, value, mode, ctx) when is_binary(path) do
    case parse_path(path, ctx) do
      %{attrs: attrs, filter: nil} ->
        multi? = multi_valued?(attrs, ctx)
        update_attr(resource, attrs, &set_value(&1, value, mode, multi?, ctx), path)

      %{attrs: attrs, filter: filter, sub: sub} ->
        update_attr(
          resource,
          attrs,
          fn
            list when is_list(list) -> set_matching(list, filter, sub, value, mode, path, ctx)
            nil when mode == :add -> set_matching([], filter, sub, value, mode, path, ctx)
            _ -> raise_no_target(path)
          end,
          path
        )
    end
  end

  defp apply_remove(resource, %{"path" => path} = operation, ctx) when is_binary(path) do
    case {parse_path(path, ctx), operation["value"]} do
      {%{attrs: attrs, filter: nil}, values} when is_list(values) ->
        update_existing_attr(resource, attrs, path, fn
          list when is_list(list) -> Enum.reject(list, &listed?(&1, values))
          other -> other
        end)

      {%{attrs: attrs, filter: nil}, _} ->
        remove_attr(resource, attrs, path)

      {%{attrs: attrs, filter: filter, sub: sub}, _} ->
        update_existing_attr(resource, attrs, path, fn
          list when is_list(list) -> remove_matching(list, filter, sub, path)
          other -> other
        end)
    end
  end

  defp apply_remove(_resource, _operation, _ctx) do
    raise PatchError, message: "Remove operation requires a path", scim_type: :no_target
  end

  defp merge_attributes(resource, attributes, mode, ctx) do
    Enum.reduce(attributes, resource, fn {name, value}, acc ->
      multi? = multi_valued?([name], ctx)
      update_attr(acc, [name], &set_value(&1, value, mode, multi?, ctx), name)
    end)
  end

  defp set_value(existing, value, :add, _multi?, _ctx) when is_list(existing) do
    existing ++ List.wrap(value)
  end

  defp set_value(nil, value, :add, true, _ctx), do: List.wrap(value)

  # add and replace keep sub-attributes the value omits (RFC 7644 section 3.5.2.3).
  defp set_value(existing, value, mode, false, ctx)
       when is_map(existing) and not is_struct(existing) and is_map(value) do
    merge_attributes(existing, value, mode, ctx)
  end

  defp set_value(_existing, value, _mode, _multi?, _ctx), do: value

  defp set_matching(list, filter, sub, value, mode, path, ctx) do
    {updated, matched?} =
      Enum.map_reduce(list, false, fn element, matched? ->
        if matches?(filter, element) do
          {set_element(element, sub, value, mode, path, ctx), true}
        else
          {element, matched?}
        end
      end)

    case {matched?, mode, filter} do
      {true, _, _} ->
        updated

      {false, :add, {:eq, attr, expected}} ->
        new_element = update_attr(%{}, String.split(attr, "."), fn _ -> expected end, path)
        list ++ [set_element(new_element, sub, value, :add, path, ctx)]

      _ ->
        raise_no_target(path)
    end
  end

  defp set_element(_element, nil, value, :replace, _path, _ctx), do: value

  defp set_element(element, nil, value, :add, path, ctx) when is_map(value) do
    if is_map(element),
      do: merge_attributes(element, value, :add, ctx),
      else: raise_no_target(path)
  end

  defp set_element(_element, nil, _value, :add, path, _ctx), do: raise_no_target(path)

  defp set_element(element, sub, value, mode, path, ctx) do
    update_attr(element, [sub], &set_value(&1, value, mode, false, ctx), path)
  end

  defp remove_matching(list, filter, nil, _path) do
    Enum.reject(list, &matches?(filter, &1))
  end

  defp remove_matching(list, filter, sub, path) do
    Enum.map(list, fn element ->
      if matches?(filter, element), do: remove_attr(element, [sub], path), else: element
    end)
  end

  defp listed?(element, values) do
    Enum.any?(values, fn
      %{"value" => value} -> get_attr(element, ["value"]) == value
      value -> element == value
    end)
  end

  # Path parsing

  defp parse_path(path, ctx) do
    with {:ok, [parsed], "", _, _, _} <- Path.path(path),
         attrs when length(attrs) <= 2 <- String.split(parsed.attribute, ".") do
      %{
        attrs: extension_attrs(parsed[:schema], attrs, ctx),
        filter: parse_filter(parsed[:filter], path),
        sub: parsed[:sub]
      }
    else
      _ -> raise PatchError, message: "Invalid path: #{inspect(path)}", scim_type: :invalid_path
    end
  end

  # Attributes of an extension schema live in an object keyed by its URN.
  defp extension_attrs(nil, attrs, _ctx), do: attrs
  defp extension_attrs(_schema, attrs, %{domain?: true}), do: attrs

  defp extension_attrs(schema, attrs, ctx) do
    if String.downcase(schema) == String.downcase(ctx.core_schema),
      do: attrs,
      else: [schema | attrs]
  end

  defp parse_filter(nil, _path), do: nil

  defp parse_filter(filter, path) do
    case Filter.filter(filter) do
      {:ok, [ast], "", _, _, _} ->
        ast

      _ ->
        raise PatchError,
          message: "Invalid filter in path: #{inspect(path)}",
          scim_type: :invalid_filter
    end
  end

  # Filter matching

  defp matches?({:and, left, right}, element),
    do: matches?(left, element) and matches?(right, element)

  defp matches?({:or, left, right}, element),
    do: matches?(left, element) or matches?(right, element)

  defp matches?({:not, expr}, element), do: not matches?(expr, element)

  defp matches?({:pr, attr}, element) do
    get_attr(element, String.split(attr, ".")) not in [nil, "", []]
  end

  defp matches?({:ne, attr, expected}, element), do: not matches?({:eq, attr, expected}, element)

  defp matches?({op, attr, expected}, element) do
    case scalar_string(get_attr(element, String.split(attr, "."))) do
      nil -> false
      actual -> compare(op, actual, to_string(expected))
    end
  end

  defp compare(:eq, actual, expected), do: actual == expected
  defp compare(:co, actual, expected), do: String.contains?(actual, expected)
  defp compare(:sw, actual, expected), do: String.starts_with?(actual, expected)
  defp compare(:ew, actual, expected), do: String.ends_with?(actual, expected)
  defp compare(:gt, actual, expected), do: actual > expected
  defp compare(:ge, actual, expected), do: actual >= expected
  defp compare(:lt, actual, expected), do: actual < expected
  defp compare(:le, actual, expected), do: actual <= expected

  defp scalar_string(value) when is_binary(value), do: value
  defp scalar_string(value) when is_number(value) or is_boolean(value), do: to_string(value)
  defp scalar_string(_value), do: nil

  # Attribute access

  defp get_attr(value, []), do: value

  defp get_attr(container, [name | rest]) when is_map(container) do
    case resolve_key(container, name) do
      nil -> nil
      key -> get_attr(Map.get(container, key), rest)
    end
  end

  defp get_attr(_value, _names), do: nil

  defp update_attr(container, [name], fun, _path) when is_map(container) do
    case resolve_key(container, name) || new_key(container, name) do
      nil -> container
      key -> Map.put(container, key, fun.(Map.get(container, key)))
    end
  end

  defp update_attr(container, [name | rest], fun, path) when is_map(container) do
    case resolve_key(container, name) do
      nil when is_struct(container) ->
        container

      nil ->
        case new_key(container, name) do
          nil -> raise_no_target(path)
          key -> Map.put(container, key, update_attr(%{}, rest, fun, path))
        end

      key ->
        nested = update_attr(Map.get(container, key) || %{}, rest, fun, path)
        Map.put(container, key, nested)
    end
  end

  defp update_attr(_container, _names, _fun, path), do: raise_no_target(path)

  defp update_existing_attr(container, [name | rest], path, fun) when is_map(container) do
    case resolve_key(container, name) do
      nil ->
        container

      key ->
        new_value =
          case rest do
            [] -> fun.(Map.get(container, key))
            _ -> update_existing_attr(Map.get(container, key), rest, path, fun)
          end

        Map.put(container, key, new_value)
    end
  end

  defp update_existing_attr(nil, _names, _path, _fun), do: nil
  defp update_existing_attr(_container, _names, path, _fun), do: raise_no_target(path)

  defp remove_attr(container, [name | rest], path) when is_map(container) do
    case {resolve_key(container, name), rest} do
      {nil, _} -> container
      {key, []} when is_struct(container) -> Map.put(container, key, nil)
      {key, []} -> Map.delete(container, key)
      {key, _} -> Map.put(container, key, remove_attr(Map.get(container, key), rest, path))
    end
  end

  defp remove_attr(nil, _names, _path), do: nil
  defp remove_attr(_container, _names, path), do: raise_no_target(path)

  # SCIM attribute names are case-insensitive (RFC 7643 section 2.1).
  defp resolve_key(container, name) do
    if Map.has_key?(container, name) do
      name
    else
      container
      |> Map.keys()
      |> Enum.find(&key_matches?(&1, name))
    end
  end

  defp key_matches?(key, name) when is_binary(key),
    do: String.downcase(key) == String.downcase(name)

  # Deprecated: atom keys of structs and domain maps (`:user_name` for `userName`).
  defp key_matches?(:__struct__, _name), do: false

  defp key_matches?(key, name) when is_atom(key),
    do: strip_underscores(key) == strip_underscores(name)

  defp key_matches?(_key, _name), do: false

  defp new_key(container, _name) when is_struct(container), do: nil

  defp new_key(container, name) do
    if Enum.any?(Map.keys(container), &is_atom/1) do
      name |> underscore() |> existing_atom()
    else
      name
    end
  end

  defp strip_underscores(key),
    do: key |> to_string() |> String.replace("_", "") |> String.downcase()

  defp underscore(name) do
    name |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1_\\2") |> String.downcase()
  end

  defp existing_atom(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> nil
  end

  defp multi_valued?(attrs, ctx),
    do: String.downcase(to_string(List.last(attrs))) in ctx.multi_valued

  defp raise_no_target(path) do
    raise PatchError,
      message: "Path #{inspect(path)} did not yield a valid target",
      scim_type: :no_target
  end
end
