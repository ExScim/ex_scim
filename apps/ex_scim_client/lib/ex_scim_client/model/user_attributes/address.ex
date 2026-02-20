defmodule ExScimClient.Model.UserAttributes.Address do
  @moduledoc """
  Postal address.
  """

  @derive JSON.Encoder
  defstruct [
    :formatted,
    :streetAddress,
    :locality,
    :region,
    :postalCode,
    :country,
    :type,
    :primary
  ]

  @type t :: %__MODULE__{
          :formatted => String.t() | nil,
          :streetAddress => String.t() | nil,
          :locality => String.t() | nil,
          :region => String.t() | nil,
          :postalCode => String.t() | nil,
          :country => String.t() | nil,
          :type => String.t() | nil,
          :primary => boolean() | nil
        }

  @doc false
  def decode(value) do
    value
  end
end
