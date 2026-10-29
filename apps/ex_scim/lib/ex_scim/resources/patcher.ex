defmodule ExScim.Resources.Patcher do
  @moduledoc false
  # Shared implementation of `ExScim.Users.Patcher` and `ExScim.Groups.Patcher`.

  alias ExScim.Parser.Filter
  alias ExScim.Parser.Path
  alias ExScim.Resources.PatchError

  @spec patch(map() | struct(), map(), [String.t()]) ::
          {:ok, map() | struct()}
          | {:error, {:invalid_patch, ExScim.Error.scim_type(), String.t()}}
  def patch(resource, %{"Operations" => operations}, multi_valued) when is_list(operations) do
    if length(operations) == 0 do
      invalid_patch("Operations array cannot be empty")
    else
      multi_valued = Enum.map(multi_valued, &normalize/1)

      try do
        updated =
          Enum.reduce(operations, resource, fn op, acc ->
            apply_op(acc, op, multi_valued)
          end)

        {:ok, updated}
      rescue
        e in PatchError -> {:error, {:invalid_patch, e.scim_type, e.message}}
      end
    end
  end

  def patch(_resource, patch_ops, _multi_valued) do
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

  defp apply_op(resource, %{"op" => op} = operation, multi) when is_binary(op) do
    case String.downcase(op) do
      "add" -> apply_add(resource, operation, multi)
      "replace" -> apply_replace(resource, operation, multi)
      "remove" -> apply_remove(resource, operation)
      other -> raise PatchError, "Unsupported op: #{inspect(other)}"
    end
  end

  defp apply_op(_resource, operation, _multi) do
    raise PatchError, "Invalid operation: #{inspect(operation)} - missing or invalid 'op' field"
  end

  defp apply_add(resource, %{"value" => value} = operation, multi) do
    apply_set(resource, operation["path"], value, :add, multi)
  end

  defp apply_add(_resource, operation, _multi) do
    raise PatchError,
      message: "Add operation missing required 'value' field: #{inspect(operation)}",
      scim_type: :invalid_value
  end

  defp apply_replace(resource, %{"value" => value} = operation, multi) do
    apply_set(resource, operation["path"], value, :replace, multi)
  end

  defp apply_replace(_resource, operation, _multi) do
    raise PatchError,
      message: "Replace operation missing required 'value' field: #{inspect(operation)}",
      scim_type: :invalid_value
  end

  defp apply_set(resource, nil, value, mode, multi) when is_map(value) do
    merge_attributes(resource, value, mode, multi)
  end

  defp apply_set(_resource, nil, value, _mode, _multi) do
    raise PatchError,
      message: "Operation without a path requires an object value, got: #{inspect(value)}",
      scim_type: :invalid_value
  end

  defp apply_set(resource, path, value, mode, multi) when is_binary(path) do
    case parse_path(path) do
      %{attrs: attrs, filter: nil} ->
        multi? = multi_valued?(attrs, multi)
        update_attr(resource, attrs, &set_value(&1, value, mode, multi?, multi), path)

      %{attrs: attrs, filter: filter, sub: sub} ->
        update_attr(
          resource,
          attrs,
          fn
            list when is_list(list) -> set_matching(list, filter, sub, value, mode, path, multi)
            nil when mode == :add -> set_matching([], filter, sub, value, mode, path, multi)
            _ -> raise_no_target(path)
          end,
          path
        )
    end
  end

  defp apply_remove(resource, %{"path" => path} = operation) when is_binary(path) do
    case {parse_path(path), operation["value"]} do
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

  defp apply_remove(_resource, _operation) do
    raise PatchError, message: "Remove operation requires a path", scim_type: :no_target
  end

  defp merge_attributes(resource, attributes, mode, multi) do
    Enum.reduce(attributes, resource, fn {name, value}, acc ->
      multi? = multi_valued?([name], multi)
      update_attr(acc, [name], &set_value(&1, value, mode, multi?, multi), name)
    end)
  end

  defp set_value(existing, value, :add, _multi?, _multi) when is_list(existing) do
    existing ++ List.wrap(value)
  end

  defp set_value(nil, value, :add, true, _multi), do: List.wrap(value)

  defp set_value(existing, value, :add, _multi?, multi)
       when is_map(existing) and not is_struct(existing) and is_map(value) do
    merge_attributes(existing, value, :add, multi)
  end

  defp set_value(_existing, value, _mode, _multi?, _multi), do: value

  defp set_matching(list, filter, sub, value, mode, path, multi) do
    {updated, matched?} =
      Enum.map_reduce(list, false, fn element, matched? ->
        if matches?(filter, element) do
          {set_element(element, sub, value, mode, path, multi), true}
        else
          {element, matched?}
        end
      end)

    case {matched?, mode, filter} do
      {true, _, _} ->
        updated

      {false, :add, {:eq, attr, expected}} ->
        new_element = update_attr(%{}, String.split(attr, "."), fn _ -> expected end, path)
        list ++ [set_element(new_element, sub, value, :add, path, multi)]

      _ ->
        raise_no_target(path)
    end
  end

  defp set_element(_element, nil, value, :replace, _path, _multi), do: value

  defp set_element(element, nil, value, :add, path, multi) when is_map(value) do
    if is_map(element),
      do: merge_attributes(element, value, :add, multi),
      else: raise_no_target(path)
  end

  defp set_element(_element, nil, _value, :add, path, _multi), do: raise_no_target(path)

  defp set_element(element, sub, value, mode, path, multi) do
    update_attr(element, [sub], &set_value(&1, value, mode, false, multi), path)
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

  defp parse_path(path) do
    case Path.path(path) do
      {:ok, [parsed], "", _, _, _} ->
        %{
          attrs: String.split(parsed.attribute, "."),
          filter: parse_filter(parsed[:filter], path),
          sub: parsed[:sub]
        }

      _ ->
        raise PatchError, message: "Invalid path: #{inspect(path)}", scim_type: :invalid_path
    end
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
        raise_no_target(path)

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

  defp resolve_key(container, name) do
    if Map.has_key?(container, name) do
      name
    else
      normalized = normalize(name)

      container
      |> Map.keys()
      |> Enum.find(&(&1 != :__struct__ and normalize(&1) == normalized))
    end
  end

  defp new_key(container, _name) when is_struct(container), do: nil

  defp new_key(container, name) do
    if Enum.any?(Map.keys(container), &is_atom/1) do
      name |> underscore() |> existing_atom()
    else
      name
    end
  end

  defp normalize(key) when is_atom(key) or is_binary(key) do
    key |> to_string() |> String.replace("_", "") |> String.downcase()
  end

  defp normalize(_key), do: nil

  defp underscore(name) do
    name |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1_\\2") |> String.downcase()
  end

  defp existing_atom(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> nil
  end

  defp multi_valued?(attrs, multi), do: normalize(List.last(attrs)) in multi

  defp raise_no_target(path) do
    raise PatchError,
      message: "Path #{inspect(path)} did not yield a valid target",
      scim_type: :no_target
  end
end
