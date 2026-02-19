defmodule ExScimClient.Model.UserAttributes.X509Certificate do
  @moduledoc """
  X.509 certificate in PEM or DER representation (as string).
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
    value
  end
end
