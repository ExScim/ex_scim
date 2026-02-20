defmodule ExScimClient.Model.Bulk.BulkRequest do
  @moduledoc """
  Bulk request (urn:ietf:params:scim:api:messages:2.0:BulkRequest)
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :failOnErrors,
    :Operations
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :failOnErrors => integer() | nil,
          :Operations => [ExScimClient.Model.Bulk.BulkOperation.t()]
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:Operations, :list, ExScimClient.Model.Bulk.BulkOperation)
  end
end
