defmodule ExScim.Groups.Patcher do
  @moduledoc """
  Applies SCIM PatchOp operations to group data (maps or structs).
  Handles multiple ops, optional path, simple/complex values, and removals.
  Supports both plain maps and domain structs with automatic key conversion.
  Filtering & schema validation can be layered in later.
  """

  @spec patch(map() | struct(), map()) :: {:ok, map() | struct()} | {:error, term()}
  def patch(group_data, %{"Operations" => operations}) when is_list(operations) do
    if length(operations) == 0 do
      {:error, "Operations array cannot be empty"}
    else
      try do
        updated =
          Enum.reduce(operations, group_data, fn op, acc ->
            apply_op(acc, op)
          end)

        {:ok, updated}
      rescue
        e -> {:error, Exception.message(e)}
      end
    end
  end

  def patch(_group_data, patch_ops) do
    cond do
      not is_map(patch_ops) ->
        {:error, "Patch operations must be a map"}

      not Map.has_key?(patch_ops, "Operations") ->
        {:error, "Missing required Operations field"}

      not is_list(patch_ops["Operations"]) ->
        {:error, "Operations must be an array"}

      true ->
        {:error, "Invalid patch operations format"}
    end
  end

  defp apply_op(resource, %{"op" => op} = operation) when is_binary(op) do
    case String.downcase(op) do
      "add" -> apply_add(resource, operation)
      "replace" -> apply_replace(resource, operation)
      "remove" -> apply_remove(resource, operation)
      other -> raise "Unsupported op: #{inspect(other)}"
    end
  end

  defp apply_op(_resource, operation) do
    raise "Invalid operation: #{inspect(operation)} - missing or invalid 'op' field"
  end

  defp apply_add(resource, %{"path" => nil, "value" => value}) do
    deep_merge(resource, value)
  end

  defp apply_add(resource, %{"path" => path, "value" => value}) when is_binary(path) do
    put_in_path(resource, path, value, :append)
  end

  defp apply_add(resource, %{"value" => value}) do
    deep_merge(resource, value)
  end

  defp apply_add(_resource, operation) do
    raise "Add operation missing required 'value' field: #{inspect(operation)}"
  end

  defp apply_replace(resource, %{"path" => nil, "value" => value}) when is_map(value) do
    if is_struct(resource) do
      merge_into_struct(resource, value)
    else
      Map.merge(resource, value)
    end
  end

  defp apply_replace(resource, %{"path" => path, "value" => value}) when is_binary(path) do
    put_in_path(resource, path, value, :replace)
  end

  defp apply_replace(resource, %{"value" => value}) do
    if is_struct(resource) do
      merge_into_struct(resource, value)
    else
      Map.merge(resource, value)
    end
  end

  defp apply_replace(_resource, operation) do
    raise "Replace operation missing required 'value' field: #{inspect(operation)}"
  end

  defp apply_remove(_resource, %{"path" => nil}) do
    %{}
  end

  defp apply_remove(resource, %{"path" => path}) do
    pop_in_path(resource, path)
  end

  defp put_in_path(resource, path, value, mode) do
    keys = String.split(path, ".")

    if is_struct(resource) do
      update_in_struct(resource, keys, fn
        nil when mode == :append -> value
        nil -> value
        existing when mode == :append and is_list(existing) -> existing ++ List.wrap(value)
        _existing when mode == :append -> value
        _ -> value
      end)
    else
      try do
        update_in(resource, keys, fn
          nil when mode == :append ->
            if is_multi_valued_field?(keys) do
              [value]
            else
              value
            end

          nil ->
            value

          existing when mode == :append and is_list(existing) ->
            existing ++ List.wrap(value)

          _existing when mode == :append ->
            [value]

          _ ->
            value
        end)
      rescue
        ArgumentError ->
          create_nested_path(resource, keys, value, mode)
      end
    end
  end

  defp create_nested_path(resource, keys, value, mode) do
    final_value =
      case mode do
        :append ->
          if is_multi_valued_field?(keys) do
            [value]
          else
            value
          end

        _ ->
          value
      end

    put_in(resource, keys, final_value)
  end

  defp is_multi_valued_field?(keys) do
    case List.last(keys) do
      field when field in ["members", "groups", "entitlements", "roles"] -> true
      _ -> false
    end
  end

  defp pop_in_path(resource, path) do
    keys = String.split(path, ".")

    if is_struct(resource) do
      {_, updated} = pop_in_struct(resource, keys)
      updated
    else
      {_, updated} = pop_in(resource, keys)
      updated
    end
  end

  defp deep_merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _k, v1, v2 ->
      deep_merge(v1, v2)
    end)
  end

  defp deep_merge(_v1, v2), do: v2

  defp merge_into_struct(struct, map) when is_map(map) do
    Enum.reduce(map, struct, fn {key, value}, acc ->
      atom_key =
        if is_binary(key) do
          try do
            String.to_existing_atom(key)
          rescue
            ArgumentError -> nil
          end
        else
          key
        end

      if atom_key && Map.has_key?(acc, atom_key) do
        Map.put(acc, atom_key, value)
      else
        acc
      end
    end)
  end

  defp update_in_struct(struct, [], fun) do
    fun.(struct)
  end

  defp update_in_struct(struct, [key], fun) when is_atom(key) do
    current_value = Map.get(struct, key)
    new_value = fun.(current_value)
    Map.put(struct, key, new_value)
  end

  defp update_in_struct(struct, [key], fun) when is_binary(key) do
    try do
      atom_key = String.to_existing_atom(key)

      if Map.has_key?(struct, atom_key) do
        update_in_struct(struct, [atom_key], fun)
      else
        struct
      end
    rescue
      ArgumentError -> struct
    end
  end

  defp update_in_struct(struct, [key | rest], fun) when is_atom(key) do
    current_value = Map.get(struct, key)
    updated_nested = update_in_struct(current_value, rest, fun)
    Map.put(struct, key, updated_nested)
  end

  defp update_in_struct(struct, [key | rest], fun) when is_binary(key) do
    try do
      atom_key = String.to_existing_atom(key)

      if Map.has_key?(struct, atom_key) do
        update_in_struct(struct, [atom_key | rest], fun)
      else
        struct
      end
    rescue
      ArgumentError -> struct
    end
  end

  defp pop_in_struct(struct, []) do
    {struct, %{}}
  end

  defp pop_in_struct(struct, [key]) when is_atom(key) do
    current_value = Map.get(struct, key)
    updated_struct = Map.put(struct, key, nil)
    {current_value, updated_struct}
  end

  defp pop_in_struct(struct, [key]) when is_binary(key) do
    atom_key = String.to_existing_atom(key)
    pop_in_struct(struct, [atom_key])
  rescue
    ArgumentError -> {nil, struct}
  end

  defp pop_in_struct(struct, [key | rest]) when is_atom(key) do
    current_value = Map.get(struct, key)
    {popped_value, updated_nested} = pop_in_struct(current_value, rest)
    updated_struct = Map.put(struct, key, updated_nested)
    {popped_value, updated_struct}
  end

  defp pop_in_struct(struct, [key | rest]) when is_binary(key) do
    atom_key = String.to_existing_atom(key)
    pop_in_struct(struct, [atom_key | rest])
  rescue
    ArgumentError -> {nil, struct}
  end
end
