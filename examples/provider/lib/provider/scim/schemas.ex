defmodule Provider.Scim.Schemas.User do
  @moduledoc """
  SCIM User schema limited to the attributes `Provider.Scim.UserMapper` stores.
  """

  use ExScim.Schema.Builder

  schema "urn:ietf:params:scim:schemas:core:2.0:User" do
    name("User")
    description("User Account")

    attribute(:userName, :string,
      description: "Unique identifier for the User",
      required: true,
      uniqueness: :server
    )

    attribute :name, :complex, description: "The components of the user's real name" do
      sub_attribute(:formatted, :string,
        description: "The full name, built from givenName and familyName",
        mutability: :read_only
      )

      sub_attribute(:familyName, :string, description: "The family name")
      sub_attribute(:givenName, :string, description: "The given name")
    end

    attribute(:displayName, :string, description: "The name of the User, suitable for display")

    attribute :emails, :complex,
      multi_valued: true,
      description: "Email address for the user; only the primary one is stored" do
      sub_attribute(:value, :string, description: "Email address for the user")

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute(:active, :boolean, description: "A Boolean value indicating the User's status")
  end
end

defmodule Provider.Scim.Schemas.Group do
  @moduledoc """
  SCIM Group schema limited to the attributes `Provider.Scim.GroupMapper` stores.
  Members are listed but can't be written through SCIM.
  """

  use ExScim.Schema.Builder

  schema "urn:ietf:params:scim:schemas:core:2.0:Group" do
    name("Group")
    description("Group")

    attribute(:displayName, :string,
      description: "A human-readable name for the Group",
      required: true
    )

    attribute :members, :complex,
      multi_valued: true,
      description: "A list of members of the Group",
      mutability: :read_only do
      sub_attribute(:value, :string,
        description: "Identifier of the member of this Group",
        mutability: :read_only
      )

      sub_attribute(:display, :string,
        description: "A human-readable name of the member",
        mutability: :read_only
      )

      sub_attribute(:"$ref", :reference,
        description: "The URI corresponding to a SCIM resource that is a member",
        reference_types: ["User", "Group"],
        mutability: :read_only
      )

      sub_attribute(:type, :string,
        description: "A label indicating the type of resource",
        canonical_values: ["User", "Group"],
        mutability: :read_only
      )
    end
  end
end
