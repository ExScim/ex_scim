defmodule ExScim.Schema.Definitions.User do
  @moduledoc """
  SCIM User schema definition using the Builder DSL.

  Defines the core User schema as specified in RFC 7643 Section 4.1.
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
      sub_attribute(:formatted, :string, description: "The full name")
      sub_attribute(:familyName, :string, description: "The family name")
      sub_attribute(:givenName, :string, description: "The given name")
      sub_attribute(:middleName, :string, description: "The middle name(s)")
      sub_attribute(:honorificPrefix, :string, description: "The honorific prefix(es)")
      sub_attribute(:honorificSuffix, :string, description: "The honorific suffix(es)")
    end

    attribute(:displayName, :string, description: "The name of the User, suitable for display")

    attribute(:nickName, :string, description: "The casual way to address the user")

    attribute(:profileUrl, :reference,
      description: "A URI that points to the user's online profile",
      reference_types: ["external"]
    )

    attribute :emails, :complex,
      multi_valued: true,
      description: "Email addresses for the user" do
      sub_attribute(:value, :string, description: "Email addresses for the user")

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes"
      )

      sub_attribute(:type, :string,
        description: "A label indicating the attribute's function",
        canonical_values: ["work", "home", "other"]
      )

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute(:active, :boolean,
      description: "A Boolean value indicating the User's administrative status"
    )

    attribute(:password, :string,
      description: "The User's cleartext password",
      mutability: :write_only,
      returned: :never
    )

    attribute(:title, :string, description: "The user's title, such as Vice President")

    attribute(:userType, :string,
      description: "Used to identify the relationship between the organization and the user"
    )

    attribute(:preferredLanguage, :string,
      description: "Indicates the User's preferred written or spoken language"
    )

    attribute(:locale, :string, description: "Used to indicate the User's default location")

    attribute(:timezone, :string,
      description: "The User's time zone in the 'Olson' time zone database format"
    )

    attribute :phoneNumbers, :complex,
      multi_valued: true,
      description: "Phone numbers for the User" do
      sub_attribute(:value, :string, description: "Phone number of the User")

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes"
      )

      sub_attribute(:type, :string,
        description: "A label indicating the attribute's function",
        canonical_values: ["work", "home", "mobile", "fax", "pager", "other"]
      )

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute :ims, :complex,
      multi_valued: true,
      description: "Instant messaging addresses for the User" do
      sub_attribute(:value, :string, description: "Instant messaging address for the User")

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes"
      )

      sub_attribute(:type, :string,
        description: "A label indicating the attribute's function",
        canonical_values: ["aim", "gtalk", "icq", "xmpp", "msn", "skype", "qq", "yahoo", "other"]
      )

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute :addresses, :complex,
      multi_valued: true,
      description: "A physical mailing address for this User" do
      sub_attribute(:formatted, :string,
        description: "The full mailing address, formatted for display or use with a mailing label"
      )

      sub_attribute(:streetAddress, :string, description: "The full street address component")
      sub_attribute(:locality, :string, description: "The city or locality component")
      sub_attribute(:region, :string, description: "The state or region component")
      sub_attribute(:postalCode, :string, description: "The zipcode or postal code component")
      sub_attribute(:country, :string, description: "The country name component")

      sub_attribute(:type, :string,
        description: "A label indicating the attribute's function",
        canonical_values: ["work", "home", "other"]
      )

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute :photos, :complex, multi_valued: true, description: "URLs of photos of the User" do
      sub_attribute(:value, :reference,
        description: "URL of a photo of the User",
        reference_types: ["external"]
      )

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes"
      )

      sub_attribute(:type, :string,
        description: "A label indicating the attribute's function",
        canonical_values: ["photo", "thumbnail"]
      )

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute :groups, :complex,
      multi_valued: true,
      description: "A list of groups to which the user belongs",
      mutability: :read_only do
      sub_attribute(:value, :string,
        description: "The identifier of the User's group",
        mutability: :immutable,
        returned: :always
      )

      sub_attribute(:"$ref", :reference,
        description: "The URI of the corresponding 'Group' resource",
        reference_types: ["User", "Group"],
        mutability: :immutable,
        returned: :always
      )

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes",
        mutability: :immutable
      )

      sub_attribute(:type, :string,
        description: "The type of group membership",
        canonical_values: ["direct", "indirect"],
        mutability: :immutable
      )
    end

    attribute :entitlements, :complex,
      multi_valued: true,
      description: "A list of entitlements for the User" do
      sub_attribute(:value, :string, description: "The value of an entitlement")

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes"
      )

      sub_attribute(:type, :string, description: "A label indicating the attribute's function")

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute :roles, :complex,
      multi_valued: true,
      description: "A list of roles for the User" do
      sub_attribute(:value, :string, description: "The value of a role")

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes"
      )

      sub_attribute(:type, :string, description: "A label indicating the attribute's function")

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end

    attribute :x509Certificates, :complex,
      multi_valued: true,
      description: "A list of certificates issued to the User" do
      sub_attribute(:value, :binary, description: "The value of an X.509 certificate")

      sub_attribute(:display, :string,
        description: "A human readable name, primarily used for display purposes"
      )

      sub_attribute(:type, :string, description: "A label indicating the attribute's function")

      sub_attribute(:primary, :boolean,
        description: "A Boolean value indicating the 'primary' or preferred attribute"
      )
    end
  end
end
