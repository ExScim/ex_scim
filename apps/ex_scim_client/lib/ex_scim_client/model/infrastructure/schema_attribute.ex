defmodule ExScimClient.Model.Infrastructure.SchemaAttribute do
  @moduledoc """
  Definition of a schema attribute.
  """

  @derive JSON.Encoder
  defstruct [
    :name,
    :type,
    :multiValued,
    :description,
    :required,
    :caseExact,
    :mutability,
    :returned,
    :uniqueness,
    :canonicalValues,
    :referenceTypes,
    :subAttributes
  ]

  @type t :: %__MODULE__{
          :name => String.t() | nil,
          :type => String.t() | nil,
          :multiValued => boolean() | nil,
          :description => String.t() | nil,
          :required => boolean() | nil,
          :caseExact => boolean() | nil,
          :mutability => String.t() | nil,
          :returned => String.t() | nil,
          :uniqueness => String.t() | nil,
          :canonicalValues => [String.t()] | nil,
          :referenceTypes => [String.t()] | nil,
          :subAttributes => [ExScimClient.Model.Infrastructure.SchemaAttribute.t()] | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(
      :subAttributes,
      :list,
      ExScimClient.Model.Infrastructure.SchemaAttribute
    )
  end
end
