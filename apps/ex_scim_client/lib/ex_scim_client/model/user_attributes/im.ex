defmodule ExScimClient.Model.UserAttributes.Im do
  @moduledoc """
  Instant messaging handle.
  """

  @derive JSON.Encoder
  defstruct [
    :value,
    :type,
    :primary
  ]

  @type t :: %__MODULE__{
          :value => String.t() | nil,
          :type => String.t() | nil,
          :primary => boolean() | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
