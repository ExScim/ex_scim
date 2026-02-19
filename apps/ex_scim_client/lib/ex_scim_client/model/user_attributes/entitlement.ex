defmodule ExScimClient.Model.UserAttributes.Entitlement do
  @moduledoc """
  Entitlement value (license, permission).
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
