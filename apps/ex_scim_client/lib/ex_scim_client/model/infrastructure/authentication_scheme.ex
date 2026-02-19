defmodule ExScimClient.Model.Infrastructure.AuthenticationScheme do
  @moduledoc """
  Supported authentication scheme.
  """

  @derive JSON.Encoder
  defstruct [
    :name,
    :description,
    :specUri,
    :documentationUri,
    :type,
    :primary
  ]

  @type t :: %__MODULE__{
          :name => String.t() | nil,
          :description => String.t() | nil,
          :specUri => Uri | nil,
          :documentationUri => Uri | nil,
          :type => String.t() | nil,
          :primary => boolean() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:specUri, :struct, ExScimClient.Model.Infrastructure.Uri)
    |> Deserializer.deserialize(:documentationUri, :struct, ExScimClient.Model.Infrastructure.Uri)
  end
end
