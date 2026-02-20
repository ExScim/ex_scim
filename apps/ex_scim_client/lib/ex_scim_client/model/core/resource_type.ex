defmodule ExScimClient.Model.Core.ResourceType do
  @moduledoc """
  Resource type definition (RFC 7643 §6)
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :meta,
    :id,
    :name,
    :endpoint,
    :description,
    :schema,
    :schemaExtensions
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :meta => ExScimClient.Model.Infrastructure.Meta.t() | nil,
          :id => String.t(),
          :name => String.t(),
          :endpoint => String.t(),
          :description => String.t() | nil,
          :schema => String.t(),
          :schemaExtensions => [ExScimClient.Model.Core.SchemaExtension.t()] | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:meta, :struct, ExScimClient.Model.Infrastructure.Meta)
    |> Deserializer.deserialize(
      :schemaExtensions,
      :list,
      ExScimClient.Model.Core.SchemaExtension
    )
  end
end
