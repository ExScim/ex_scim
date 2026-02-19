defmodule ExScimClient.Model.Infrastructure.Uri do
  @moduledoc """
  URI representation for SCIM attributes.
  """

  @derive JSON.Encoder
  defstruct [
    :value
  ]

  @type t :: %__MODULE__{
          :value => String.t() | nil
        }

  @doc false
  def decode(value) do
    case is_binary(value) do
      true -> %__MODULE__{value: value}
      false -> value
    end
  end
end
