defmodule ExScimClient.Model.Core.ServiceProviderConfig do
  @moduledoc """
  Describes the SCIM features supported by the service provider (RFC 7644 §4)
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :id,
    :meta,
    :documentationUri,
    :patch,
    :bulk,
    :filter,
    :changePassword,
    :sort,
    :etag,
    :authenticationSchemes
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :id => String.t() | nil,
          :meta => ExScimClient.Model.Infrastructure.Meta.t() | nil,
          :documentationUri => ExScimClient.Model.Infrastructure.Uri.t() | nil,
          :patch => map() | nil,
          :bulk => map() | nil,
          :filter => map() | nil,
          :changePassword => map() | nil,
          :sort => map() | nil,
          :etag => map() | nil,
          :authenticationSchemes => [ExScimClient.Model.Infrastructure.AuthenticationScheme.t()]
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:meta, :struct, ExScimClient.Model.Infrastructure.Meta)
    |> Deserializer.deserialize(:documentationUri, :struct, ExScimClient.Model.Infrastructure.Uri)
    |> Deserializer.deserialize(
      :authenticationSchemes,
      :list,
      ExScimClient.Model.Infrastructure.AuthenticationScheme
    )
  end
end
