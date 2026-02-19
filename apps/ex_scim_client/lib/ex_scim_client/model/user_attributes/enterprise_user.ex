defmodule ExScimClient.Model.UserAttributes.EnterpriseUser do
  @moduledoc """
  Enterprise User extension (urn:ietf:params:scim:schemas:extension:enterprise:2.0:User).
  """

  @derive JSON.Encoder
  defstruct [
    :employeeNumber,
    :costCenter,
    :organization,
    :division,
    :department,
    :manager
  ]

  @type t :: %__MODULE__{
          :employeeNumber => String.t() | nil,
          :costCenter => String.t() | nil,
          :organization => String.t() | nil,
          :division => String.t() | nil,
          :department => String.t() | nil,
          :manager => ExScimClient.Model.References.ManagerRef.t() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:manager, :struct, ExScimClient.Model.References.ManagerRef)
  end
end
