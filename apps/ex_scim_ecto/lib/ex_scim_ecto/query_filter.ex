defmodule ExScimEcto.QueryFilter do
  @moduledoc """
  Query filter adapter for building queries from SCIM filter ASTs.
  """

  @behaviour ExScim.QueryFilter.Adapter
  import Ecto.Query

  @impl true
  def apply_filter(query, nil), do: query

  def apply_filter(query, ast) do
    dynamic = build_dynamic(ast)
    from(q in query, where: ^dynamic)
  end

  defp build_dynamic({:eq, field, value}) do
    dynamic([u], field(u, ^to_atom(field)) == ^value)
  end

  defp build_dynamic({:ne, field, value}) do
    dynamic([u], field(u, ^to_atom(field)) != ^value)
  end

  defp build_dynamic({:co, field, value}) do
    dynamic([u], like(field(u, ^to_atom(field)), ^"%#{value}%"))
  end

  defp build_dynamic({:sw, field, value}) do
    dynamic([u], like(field(u, ^to_atom(field)), ^"#{value}%"))
  end

  defp build_dynamic({:ew, field, value}) do
    dynamic([u], like(field(u, ^to_atom(field)), ^"%#{value}"))
  end

  defp build_dynamic({:pr, field}) do
    dynamic([u], not is_nil(field(u, ^to_atom(field))))
  end

  defp build_dynamic({:gt, field, value}) do
    dynamic([u], field(u, ^to_atom(field)) > ^value)
  end

  defp build_dynamic({:ge, field, value}) do
    dynamic([u], field(u, ^to_atom(field)) >= ^value)
  end

  defp build_dynamic({:lt, field, value}) do
    dynamic([u], field(u, ^to_atom(field)) < ^value)
  end

  defp build_dynamic({:le, field, value}) do
    dynamic([u], field(u, ^to_atom(field)) <= ^value)
  end

  defp build_dynamic({:and, left, right}) do
    dynamic([u], ^build_dynamic(left) and ^build_dynamic(right))
  end

  defp build_dynamic({:or, left, right}) do
    dynamic([u], ^build_dynamic(left) or ^build_dynamic(right))
  end

  defp to_atom(term) do
    term
    |> Macro.underscore()
    |> String.to_atom()
  end
end
