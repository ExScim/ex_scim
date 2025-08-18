defmodule ExScim.QueryFilter.Adapter do
  @moduledoc """
  A behavior for converting SCIM filter ASTs into storage-level query logic.
  """

  @type filter_ast :: term()
  # Ecto queryable, ETS data, etc.
  @type data_source :: term()
  @type result :: term()

  @callback apply_filter(data_source, filter_ast) :: result
end
