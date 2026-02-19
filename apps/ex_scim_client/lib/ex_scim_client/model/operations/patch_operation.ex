defmodule ExScimClient.Model.Operations.PatchOperation do
  @moduledoc """
  Single PATCH operation.
  """

  @derive JSON.Encoder
  defstruct [
    :op,
    :path,
    :value
  ]

  @type t :: %__MODULE__{
          :op => String.t(),
          :path => String.t() | nil,
          :value => ExScimClient.Model.Operations.PatchOperationValue.t() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(
      :value,
      :struct,
      ExScimClient.Model.Operations.PatchOperationValue
    )
  end
end
