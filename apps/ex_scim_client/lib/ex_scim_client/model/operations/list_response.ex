defmodule ExScimClient.Model.Operations.ListResponse do
  @moduledoc """
  Generic SCIM ListResponse wrapper.
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :totalResults,
    :itemsPerPage,
    :startIndex,
    :Resources
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()] | nil,
          :totalResults => integer() | nil,
          :itemsPerPage => integer() | nil,
          :startIndex => integer() | nil,
          :Resources => [map()] | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
