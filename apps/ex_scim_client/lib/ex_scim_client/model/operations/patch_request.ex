defmodule ExScimClient.Model.Operations.PatchRequest do
  @moduledoc """
  SCIM PATCH request (urn:ietf:params:scim:api:messages:2.0:PatchOp)
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :Operations
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :Operations => [ExScimClient.Model.Operations.PatchOperation.t()]
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:Operations, :list, ExScimClient.Model.Operations.PatchOperation)
  end
end
