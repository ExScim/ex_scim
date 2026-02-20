defmodule ExScimClient.Model.Bulk.BulkOperationResult do
  @moduledoc """
  Result of a bulk operation.
  """

  @derive JSON.Encoder
  defstruct [
    :method,
    :bulkId,
    :location,
    :status,
    :response,
    :version
  ]

  @type t :: %__MODULE__{
          :method => String.t() | nil,
          :bulkId => String.t() | nil,
          :location => Uri | nil,
          :status => String.t() | nil,
          :response => map() | nil,
          :version => String.t() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:location, :struct, ExScimClient.Model.Infrastructure.Uri)
  end
end
