defmodule ExScim.Schema.Definitions.Group do
  @moduledoc """
  SCIM Group schema definition using the Builder DSL.

  Defines the Group schema as specified in RFC 7643 Section 4.2.
  """

  use ExScim.Schema.Builder

  schema "urn:ietf:params:scim:schemas:core:2.0:Group" do
    name "Group"
    description "Group"

    attribute :displayName, :string,
      description: "A human-readable name for the Group",
      required: true

    attribute :members, :complex, multi_valued: true, description: "A list of members of the Group" do
      sub_attribute :value, :string,
        description: "Identifier of the member of this Group",
        mutability: :immutable
      sub_attribute :"$ref", :reference,
        description: "The URI corresponding to a SCIM resource that is a member",
        reference_types: ["User", "Group"],
        mutability: :immutable
      sub_attribute :type, :string,
        description: "A label indicating the type of resource",
        canonical_values: ["User", "Group"],
        mutability: :immutable
    end
  end
end
