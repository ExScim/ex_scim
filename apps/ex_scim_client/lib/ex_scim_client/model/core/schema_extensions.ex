defmodule ExScimClient.Model.Core.SchemaExtension do
  @moduledoc """
  Schema extension declaration.
  """

  @derive JSON.Encoder
  defstruct [
    :schema,
    :required
  ]

  @type t :: %__MODULE__{
          :schema => String.t() | nil,
          :required => boolean() | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
