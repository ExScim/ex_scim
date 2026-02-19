defmodule ExScimClient.Model.Core.Schema do
  @moduledoc """
  SCIM schema definition (RFC 7643 §7)
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :meta,
    :id,
    :name,
    :description,
    :attributes
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :meta => ExScimClient.Model.Infrastructure.Meta.t() | nil,
          :id => String.t(),
          :name => String.t(),
          :description => String.t() | nil,
          :attributes => [ExScimClient.Model.Infrastructure.SchemaAttribute.t()]
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:meta, :struct, ExScimClient.Model.Infrastructure.Meta)
    |> Deserializer.deserialize(
      :attributes,
      :list,
      ExScimClient.Model.Infrastructure.SchemaAttribute
    )
  end
end
