defmodule ExScimClient.Model.UserAttributes.Role do
  @moduledoc """
  Role value.
  """

  @derive JSON.Encoder
  defstruct [
    :value,
    :type,
    :display,
    :primary
  ]

  @type t :: %__MODULE__{
          :value => String.t() | nil,
          :type => String.t() | nil,
          :display => String.t() | nil,
          :primary => boolean() | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
