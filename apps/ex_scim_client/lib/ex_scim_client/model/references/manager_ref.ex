defmodule ExScimClient.Model.References.ManagerRef do
  @moduledoc """
  Reference to a manager User resource.
  """

  @derive JSON.Encoder
  defstruct [
    :value,
    :"$ref",
    :displayName
  ]

  @type t :: %__MODULE__{
          :value => String.t() | nil,
          :"$ref" => Uri | nil,
          :displayName => String.t() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:"$ref", :struct, ExScimClient.Model.Infrastructure.Uri)
  end
end
