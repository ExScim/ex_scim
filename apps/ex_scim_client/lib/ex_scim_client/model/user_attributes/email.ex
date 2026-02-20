defmodule ExScimClient.Model.UserAttributes.Email do
  @moduledoc """
  Email address value.
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
