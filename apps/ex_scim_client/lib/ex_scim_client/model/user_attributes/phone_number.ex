defmodule ExScimClient.Model.UserAttributes.PhoneNumber do
  @moduledoc """
  Phone number value.
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
