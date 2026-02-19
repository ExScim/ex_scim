defmodule ExScimClient.Model.UserAttributes.Photo do
  @moduledoc """
  Photo reference.
  """

  @derive JSON.Encoder
  defstruct [
    :value,
    :type
  ]

  @type t :: %__MODULE__{
          :value => Uri | nil,
          :type => String.t() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:value, :struct, ExScimClient.Model.Infrastructure.Uri)
  end
end
