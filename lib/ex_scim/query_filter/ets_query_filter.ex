defmodule ExScim.QueryFilter.EtsQueryFilter do
  @moduledoc """
  A SCIM filter engine for ETS-based user storage.
  Evaluates filter ASTs against in-memory user maps.
  """

  @behaviour ExScim.QueryFilter.Adapter

  @impl true
  def apply_filter(users, nil), do: users

  def apply_filter(users, ast) do
    Enum.filter(users, fn user ->
      eval(ast, user)
    end)
  end

  defp eval({:eq, field, value}, user), do: Map.get(user, field) == value
  defp eval({:ne, field, value}, user), do: Map.get(user, field) != value
  defp eval({:co, field, value}, user), do: String.contains?(Map.get(user, field, ""), value)
  defp eval({:sw, field, value}, user), do: String.starts_with?(Map.get(user, field, ""), value)
  defp eval({:ew, field, value}, user), do: String.ends_with?(Map.get(user, field, ""), value)
  defp eval({:pr, field}, user), do: Map.has_key?(user, field) and not is_nil(user[field])
  defp eval({:gt, field, value}, user), do: Map.get(user, field) > value
  defp eval({:ge, field, value}, user), do: Map.get(user, field) >= value
  defp eval({:lt, field, value}, user), do: Map.get(user, field) < value
  defp eval({:le, field, value}, user), do: Map.get(user, field) <= value

  defp eval({:and, left, right}, user), do: eval(left, user) and eval(right, user)
  defp eval({:or, left, right}, user), do: eval(left, user) or eval(right, user)

  # fallback
  defp eval(_, _), do: false
end
