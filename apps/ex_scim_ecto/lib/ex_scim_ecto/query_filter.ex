defmodule ExScimEcto.QueryFilter do
  @moduledoc """
  Query filter adapter for building queries from SCIM filter ASTs.
  """

  @behaviour ExScim.QueryFilter.Adapter
  import Ecto.Query

  @impl true
  def apply_filter(query, nil), do: query

  def apply_filter(query, ast) do
    dynamic = build_dynamic(ast, [])
    from(q in query, where: ^dynamic)
  end

  def apply_filter(query, nil, _opts), do: query

  def apply_filter(query, ast, opts) do
    required_assocs = collect_associations(ast, opts)
    query = ensure_joins(query, required_assocs)
    dynamic = build_dynamic(ast, opts)
    query = from(q in query, where: ^dynamic)

    if MapSet.size(required_assocs) > 0 do
      from(q in query, distinct: true)
    else
      query
    end
  end

  # Comparison operators
  for op <- [:eq, :ne, :gt, :ge, :lt, :le] do
    defp build_dynamic({unquote(op), field, value}, opts) do
      apply_comparison(resolve_field(field, opts), unquote(op), value)
    end
  end

  # Like operators
  for op <- [:co, :sw, :ew] do
    defp build_dynamic({unquote(op), field, value}, opts) do
      apply_like(resolve_field(field, opts), unquote(op), value)
    end
  end

  # Present operator
  defp build_dynamic({:pr, field}, opts) do
    apply_present(resolve_field(field, opts))
  end

  # Logical operators
  defp build_dynamic({:and, left, right}, opts) do
    dynamic([], ^build_dynamic(left, opts) and ^build_dynamic(right, opts))
  end

  defp build_dynamic({:or, left, right}, opts) do
    dynamic([], ^build_dynamic(left, opts) or ^build_dynamic(right, opts))
  end

  defp build_dynamic({:not, expr}, opts) do
    dynamic([], not (^build_dynamic(expr, opts)))
  end

  # Comparison helpers — atom (root table column)
  defp apply_comparison(field, :eq, value) when is_atom(field) do
    dynamic([u], field(u, ^field) == ^value)
  end

  defp apply_comparison(field, :ne, value) when is_atom(field) do
    dynamic([u], field(u, ^field) != ^value)
  end

  defp apply_comparison(field, :gt, value) when is_atom(field) do
    dynamic([u], field(u, ^field) > ^value)
  end

  defp apply_comparison(field, :ge, value) when is_atom(field) do
    dynamic([u], field(u, ^field) >= ^value)
  end

  defp apply_comparison(field, :lt, value) when is_atom(field) do
    dynamic([u], field(u, ^field) < ^value)
  end

  defp apply_comparison(field, :le, value) when is_atom(field) do
    dynamic([u], field(u, ^field) <= ^value)
  end

  # Comparison helpers — association
  defp apply_comparison({:assoc, assoc_name, col}, :eq, value) do
    dynamic([{^assoc_name, x}], field(x, ^col) == ^value)
  end

  defp apply_comparison({:assoc, assoc_name, col}, :ne, value) do
    dynamic([{^assoc_name, x}], field(x, ^col) != ^value)
  end

  defp apply_comparison({:assoc, assoc_name, col}, :gt, value) do
    dynamic([{^assoc_name, x}], field(x, ^col) > ^value)
  end

  defp apply_comparison({:assoc, assoc_name, col}, :ge, value) do
    dynamic([{^assoc_name, x}], field(x, ^col) >= ^value)
  end

  defp apply_comparison({:assoc, assoc_name, col}, :lt, value) do
    dynamic([{^assoc_name, x}], field(x, ^col) < ^value)
  end

  defp apply_comparison({:assoc, assoc_name, col}, :le, value) do
    dynamic([{^assoc_name, x}], field(x, ^col) <= ^value)
  end

  # Like helpers — atom (root table column)
  defp apply_like(field, :co, value) when is_atom(field) do
    dynamic([u], like(field(u, ^field), ^"%#{value}%"))
  end

  defp apply_like(field, :sw, value) when is_atom(field) do
    dynamic([u], like(field(u, ^field), ^"#{value}%"))
  end

  defp apply_like(field, :ew, value) when is_atom(field) do
    dynamic([u], like(field(u, ^field), ^"%#{value}"))
  end

  # Like helpers — association
  defp apply_like({:assoc, assoc_name, col}, :co, value) do
    dynamic([{^assoc_name, x}], like(field(x, ^col), ^"%#{value}%"))
  end

  defp apply_like({:assoc, assoc_name, col}, :sw, value) do
    dynamic([{^assoc_name, x}], like(field(x, ^col), ^"#{value}%"))
  end

  defp apply_like({:assoc, assoc_name, col}, :ew, value) do
    dynamic([{^assoc_name, x}], like(field(x, ^col), ^"%#{value}"))
  end

  # Present helpers
  defp apply_present(field) when is_atom(field) do
    dynamic([u], not is_nil(field(u, ^field)))
  end

  defp apply_present({:assoc, assoc_name, col}) do
    dynamic([{^assoc_name, x}], not is_nil(field(x, ^col)))
  end

  # Field resolution

  defp resolve_field(scim_path, opts) do
    filter_mapping = Keyword.get(opts, :filter_mapping, %{})
    schema_fields = Keyword.get(opts, :schema_fields, nil)

    case Map.get(filter_mapping, scim_path) do
      nil ->
        underscore = Macro.underscore(scim_path)

        if String.contains?(underscore, ".") or String.contains?(underscore, "/") do
          raise ArgumentError,
                "Unsupported filter attribute \"#{scim_path}\". " <>
                  "Complex attribute paths require an explicit filter_mapping configuration."
        end

        atom =
          try do
            String.to_existing_atom(underscore)
          rescue
            ArgumentError ->
              raise ArgumentError, "Unknown filter attribute \"#{scim_path}\""
          end

        if schema_fields && atom not in schema_fields do
          raise ArgumentError, "Unknown filter attribute \"#{scim_path}\""
        end

        atom

      mapped_atom when is_atom(mapped_atom) ->
        mapped_atom

      {:assoc, assoc_name, field_name} = assoc_ref
      when is_atom(assoc_name) and is_atom(field_name) ->
        assoc_ref
    end
  end

  # Association collection — walks the AST and collects unique association names

  defp collect_associations(ast, opts) do
    do_collect_associations(ast, opts, MapSet.new())
  end

  defp do_collect_associations(nil, _opts, acc), do: acc

  defp do_collect_associations({op, field, _value}, opts, acc)
       when op in [:eq, :ne, :co, :sw, :ew, :gt, :ge, :lt, :le] do
    case resolve_field(field, opts) do
      {:assoc, assoc_name, _col} -> MapSet.put(acc, assoc_name)
      _atom -> acc
    end
  end

  defp do_collect_associations({:pr, field}, opts, acc) do
    case resolve_field(field, opts) do
      {:assoc, assoc_name, _col} -> MapSet.put(acc, assoc_name)
      _atom -> acc
    end
  end

  defp do_collect_associations({op, left, right}, opts, acc) when op in [:and, :or] do
    acc = do_collect_associations(left, opts, acc)
    do_collect_associations(right, opts, acc)
  end

  defp do_collect_associations({:not, expr}, opts, acc) do
    do_collect_associations(expr, opts, acc)
  end

  # Join management

  defp ensure_joins(query, assoc_names) do
    Enum.reduce(assoc_names, query, fn assoc_name, q ->
      if has_named_binding?(q, assoc_name) do
        q
      else
        from(root in q,
          left_join: assoc in assoc(root, ^assoc_name),
          as: ^assoc_name
        )
      end
    end)
  end
end
