defmodule ExScimClient.Model.Operations.SearchRequest do
  @moduledoc """
  .search request (urn:ietf:params:scim:api:messages:2.0:SearchRequest)
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :attributes,
    :excludedAttributes,
    :filter,
    :sortBy,
    :sortOrder,
    :startIndex,
    :count
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :attributes => [String.t()] | nil,
          :excludedAttributes => [String.t()] | nil,
          :filter => String.t() | nil,
          :sortBy => String.t() | nil,
          :sortOrder => String.t() | nil,
          :startIndex => integer() | nil,
          :count => integer() | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
