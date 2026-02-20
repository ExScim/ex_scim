defmodule ExScimClient.Model.Core.Group do
  @moduledoc """
  SCIM Group resource (core: urn:ietf:params:scim:schemas:core:2.0:Group).
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :id,
    :externalId,
    :meta,
    :displayName,
    :members
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :id => String.t() | nil,
          :externalId => String.t() | nil,
          :meta => ExScimClient.Model.Infrastructure.Meta.t() | nil,
          :displayName => String.t(),
          :members => [ExScimClient.Model.References.MemberRef.t()] | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:meta, :struct, ExScimClient.Model.Infrastructure.Meta)
    |> Deserializer.deserialize(:members, :list, ExScimClient.Model.References.MemberRef)
  end
end
