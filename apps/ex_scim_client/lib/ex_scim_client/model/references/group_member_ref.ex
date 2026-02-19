defmodule ExScimClient.Model.References.GroupMemberRef do
  @moduledoc """
  Entry in User.groups (read-only).
  """

  @derive JSON.Encoder
  defstruct [
    :value,
    :"$ref",
    :display,
    :type
  ]

  @type t :: %__MODULE__{
          :value => String.t() | nil,
          :"$ref" => Uri | nil,
          :display => String.t() | nil,
          :type => String.t() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:"$ref", :struct, ExScimClient.Model.Infrastructure.Uri)
  end
end
