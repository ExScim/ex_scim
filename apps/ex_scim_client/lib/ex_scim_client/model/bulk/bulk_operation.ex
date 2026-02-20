defmodule ExScimClient.Model.Bulk.BulkOperation do
  @moduledoc """
  A single operation in a bulk request.
  """

  @derive JSON.Encoder
  defstruct [
    :method,
    :path,
    :bulkId,
    :version,
    :data
  ]

  @type t :: %__MODULE__{
          :method => String.t(),
          :path => String.t() | nil,
          :bulkId => String.t() | nil,
          :version => String.t() | nil,
          :data => map() | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
