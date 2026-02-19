defmodule ExScimClient.Model.Bulk.BulkResponse do
  @moduledoc """
  Bulk response (urn:ietf:params:scim:api:messages:2.0:BulkResponse)
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :Operations
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :Operations => [ExScimClient.Model.Bulk.BulkOperationResult.t()]
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:Operations, :list, ExScimClient.Model.Bulk.BulkOperationResult)
  end
end
