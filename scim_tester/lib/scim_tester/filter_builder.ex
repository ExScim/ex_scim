defmodule ScimTester.FilterBuilder do
  @moduledoc """
  Builds `ExScimClient.Filter` expressions from the UI's filter rows.

  A filter row is a map with `:attribute`, `:operator`, and `:value` keys.
  Rows that are blank (no attribute/operator, or no value for operators that
  require one) are ignored.
  """

  alias ExScimClient.Filter

  @operators [
    {"eq", "equals"},
    {"ne", "not equal"},
    {"co", "contains"},
    {"sw", "starts with"},
    {"ew", "ends with"},
    {"gt", "greater than"},
    {"ge", "greater or equal"},
    {"lt", "less than"},
    {"le", "less or equal"},
    {"pr", "present"}
  ]

  @doc "List of `{operator, label}` tuples for rendering operator selects."
  def operators, do: @operators

  @doc """
  Combines the given filter rows into a single filter using `combinator`
  (`"and"` or `"or"`). Returns `nil` when no rows are filled in.
  """
  def build(rows, combinator) do
    valid_rows =
      Enum.filter(rows, fn row ->
        row.attribute != "" and row.operator != "" and
          (row.operator == "pr" or (row.value != nil and row.value != ""))
      end)

    case valid_rows do
      [] ->
        nil

      [single] ->
        build_single(single)

      [first | rest] ->
        combine_fn = if combinator == "or", do: &Filter.or1/2, else: &Filter.and1/2

        Enum.reduce(rest, build_single(first), fn row, acc ->
          combine_fn.(acc, build_single(row))
        end)
    end
  end

  defp build_single(%{attribute: attr, operator: op, value: val}) do
    filter = Filter.new()

    case op do
      "eq" -> Filter.equals(filter, attr, val)
      "ne" -> Filter.not_equal(filter, attr, val)
      "co" -> Filter.contains(filter, attr, val)
      "sw" -> Filter.starts_with(filter, attr, val)
      "ew" -> Filter.ends_with(filter, attr, val)
      "gt" -> Filter.greater_than(filter, attr, val)
      "ge" -> Filter.greater_or_equal(filter, attr, val)
      "lt" -> Filter.less_than(filter, attr, val)
      "le" -> Filter.less_or_equal(filter, attr, val)
      "pr" -> Filter.present(filter, attr, nil)
    end
  end
end
