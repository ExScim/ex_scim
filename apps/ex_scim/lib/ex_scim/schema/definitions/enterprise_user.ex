defmodule ExScim.Schema.Definitions.EnterpriseUser do
  @moduledoc """
  SCIM EnterpriseUser schema extension definition using the Builder DSL.

  Defines the Enterprise User extension schema as specified in RFC 7643 Section 4.3.
  """

  use ExScim.Schema.Builder

  schema "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" do
    name "EnterpriseUser"
    description "Enterprise User"

    attribute :employeeNumber, :string,
      description: "Numeric or alphanumeric identifier assigned to a person"

    attribute :organization, :string, description: "Identifies the name of an organization"

    attribute :division, :string, description: "Identifies the name of a division"

    attribute :department, :string, description: "Identifies the name of a department"

    attribute :manager, :complex, description: "The User's manager" do
      sub_attribute :value, :string,
        description: "The id of the SCIM resource representing the User's manager"
      sub_attribute :"$ref", :reference,
        description: "The URI of the SCIM resource representing the User's manager",
        reference_types: ["User"]
      sub_attribute :displayName, :string,
        description: "The displayName of the User's manager",
        mutability: :read_only
    end
  end
end
