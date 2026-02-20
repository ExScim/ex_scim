defmodule ExScimClient.Model.UserAttributes.Name do
  @moduledoc """
  User name components.
  """

  @derive JSON.Encoder
  defstruct [
    :formatted,
    :familyName,
    :givenName,
    :middleName,
    :honorificPrefix,
    :honorificSuffix
  ]

  @type t :: %__MODULE__{
          :formatted => String.t() | nil,
          :familyName => String.t() | nil,
          :givenName => String.t() | nil,
          :middleName => String.t() | nil,
          :honorificPrefix => String.t() | nil,
          :honorificSuffix => String.t() | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
