defmodule ExScimClient.Model.Infrastructure.Meta do
  @moduledoc """
  Common resource metadata.
  """

  @derive JSON.Encoder
  defstruct [
    :resourceType,
    :created,
    :lastModified,
    :version,
    :location
  ]

  @type t :: %__MODULE__{
          :resourceType => String.t() | nil,
          :created => DateTime.t() | nil,
          :lastModified => DateTime.t() | nil,
          :version => String.t() | nil,
          :location => Uri | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:location, :struct, ExScimClient.Model.Infrastructure.Uri)
  end
end
