defmodule ExScim.QueryFilter.Adapter do
  @moduledoc """
  Behaviour for converting SCIM filter ASTs into storage-level query logic.

  The SCIM filter parser produces a nested tuple AST representing filter
  expressions. Implementations translate this AST into queries appropriate
  for their storage backend (e.g. Ecto where clauses, ETS match specs).

  ## AST structure

  Single comparisons:

      {:eq, "userName", "alice"}
      {:co, "displayName", "john"}
      {:sw, "email", "admin@"}
      {:gt, "meta.lastModified", "2024-01-01T00:00:00Z"}

  Logical operators:

      {:and, left_ast, right_ast}
      {:or, left_ast, right_ast}
      {:not, inner_ast}

  ## Implementations

  - `ExScim.QueryFilter.EtsQueryFilter` - filters in-memory ETS lists
  - `ExScimEcto.QueryFilter` - translates to Ecto `where` clauses
  """

  @typedoc """
  A SCIM filter AST node.

  Comparison tuples like `{:eq, field, value}` or logical combinators
  like `{:and, left, right}`. `nil` means no filter is applied.
  """
  @type filter_ast :: term()

  @typedoc "The data source to filter: an Ecto queryable, a list of maps, etc."
  @type data_source :: term()

  @typedoc "The filtered result: a modified Ecto query, a filtered list, etc."
  @type result :: term()

  @doc "Applies the filter AST to the given data source, returning a filtered result."
  @callback apply_filter(data_source, filter_ast) :: result
end
