defmodule ExScim.Schema.Repository.LegacyRepository do
  @moduledoc """
  Original RFC 7643 schema definitions (hardcoded maps).

  This module is preserved for backwards compatibility and as the verification
  source of truth for the new DSL-based schema definitions.
  """

  @behaviour ExScim.Schema.Repository.Adapter

  import ExScim.Config

  @user_schema %{
    "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Schema"],
    "id" => "urn:ietf:params:scim:schemas:core:2.0:User",
    "name" => "User",
    "description" => "User Account",
    "attributes" => [
      %{
        "name" => "userName",
        "type" => "string",
        "multiValued" => false,
        "description" => "Unique identifier for the User",
        "required" => true,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "server"
      },
      %{
        "name" => "name",
        "type" => "complex",
        "multiValued" => false,
        "description" => "The components of the user's real name",
        "required" => false,
        "subAttributes" => [
          %{
            "name" => "formatted",
            "type" => "string",
            "multiValued" => false,
            "description" => "The full name",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "familyName",
            "type" => "string",
            "multiValued" => false,
            "description" => "The family name",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "givenName",
            "type" => "string",
            "multiValued" => false,
            "description" => "The given name",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          }
        ],
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "displayName",
        "type" => "string",
        "multiValued" => false,
        "description" => "The name of the User, suitable for display",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "emails",
        "type" => "complex",
        "multiValued" => true,
        "description" => "Email addresses for the user",
        "required" => false,
        "subAttributes" => [
          %{
            "name" => "value",
            "type" => "string",
            "multiValued" => false,
            "description" => "Email addresses for the user",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "display",
            "type" => "string",
            "multiValued" => false,
            "description" => "A human readable name, primarily used for display purposes",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "type",
            "type" => "string",
            "multiValued" => false,
            "description" => "A label indicating the attribute's function",
            "required" => false,
            "caseExact" => false,
            "canonicalValues" => ["work", "home", "other"],
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "primary",
            "type" => "boolean",
            "multiValued" => false,
            "description" => "A Boolean value indicating the 'primary' or preferred attribute",
            "required" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          }
        ],
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "active",
        "type" => "boolean",
        "multiValued" => false,
        "description" => "A Boolean value indicating the User's administrative status",
        "required" => false,
        "mutability" => "readWrite",
        "returned" => "default"
      },
      %{
        "name" => "title",
        "type" => "string",
        "multiValued" => false,
        "description" => "The user's title, such as Vice President",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "userType",
        "type" => "string",
        "multiValued" => false,
        "description" =>
          "Used to identify the relationship between the organization and the user",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "preferredLanguage",
        "type" => "string",
        "multiValued" => false,
        "description" => "Indicates the User's preferred written or spoken language",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "locale",
        "type" => "string",
        "multiValued" => false,
        "description" => "Used to indicate the User's default location",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "timezone",
        "type" => "string",
        "multiValued" => false,
        "description" => "The User's time zone in the 'Olson' time zone database format",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "phoneNumbers",
        "type" => "complex",
        "multiValued" => true,
        "description" => "Phone numbers for the User",
        "required" => false,
        "subAttributes" => [
          %{
            "name" => "value",
            "type" => "string",
            "multiValued" => false,
            "description" => "Phone number of the User",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "display",
            "type" => "string",
            "multiValued" => false,
            "description" => "A human readable name, primarily used for display purposes",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "type",
            "type" => "string",
            "multiValued" => false,
            "description" => "A label indicating the attribute's function",
            "required" => false,
            "caseExact" => false,
            "canonicalValues" => ["work", "home", "mobile", "fax", "pager", "other"],
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "primary",
            "type" => "boolean",
            "multiValued" => false,
            "description" => "A Boolean value indicating the 'primary' or preferred attribute",
            "required" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          }
        ],
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "addresses",
        "type" => "complex",
        "multiValued" => true,
        "description" => "A physical mailing address for this User",
        "required" => false,
        "subAttributes" => [
          %{
            "name" => "formatted",
            "type" => "string",
            "multiValued" => false,
            "description" =>
              "The full mailing address, formatted for display or use with a mailing label",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "streetAddress",
            "type" => "string",
            "multiValued" => false,
            "description" => "The full street address component",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "locality",
            "type" => "string",
            "multiValued" => false,
            "description" => "The city or locality component",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "region",
            "type" => "string",
            "multiValued" => false,
            "description" => "The state or region component",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "postalCode",
            "type" => "string",
            "multiValued" => false,
            "description" => "The zipcode or postal code component",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "country",
            "type" => "string",
            "multiValued" => false,
            "description" => "The country name component",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "type",
            "type" => "string",
            "multiValued" => false,
            "description" => "A label indicating the attribute's function",
            "required" => false,
            "caseExact" => false,
            "canonicalValues" => ["work", "home", "other"],
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "primary",
            "type" => "boolean",
            "multiValued" => false,
            "description" => "A Boolean value indicating the 'primary' or preferred attribute",
            "required" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          }
        ],
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "photos",
        "type" => "complex",
        "multiValued" => true,
        "description" => "URLs of photos of the User",
        "required" => false,
        "subAttributes" => [
          %{
            "name" => "value",
            "type" => "reference",
            "referenceTypes" => ["external"],
            "multiValued" => false,
            "description" => "URL of a photo of the User",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "display",
            "type" => "string",
            "multiValued" => false,
            "description" => "A human readable name, primarily used for display purposes",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "type",
            "type" => "string",
            "multiValued" => false,
            "description" => "A label indicating the attribute's function",
            "required" => false,
            "caseExact" => false,
            "canonicalValues" => ["photo", "thumbnail"],
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "primary",
            "type" => "boolean",
            "multiValued" => false,
            "description" => "A Boolean value indicating the 'primary' or preferred attribute",
            "required" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          }
        ],
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      }
    ],
    "meta" => %{
      "resourceType" => "Schema",
      "location" => "#{base_url()}/scim/v2/Schemas/urn:ietf:params:scim:schemas:core:2.0:User"
    }
  }

  @enterprise_user_schema %{
    "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Schema"],
    "id" => "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User",
    "name" => "EnterpriseUser",
    "description" => "Enterprise User",
    "attributes" => [
      %{
        "name" => "employeeNumber",
        "type" => "string",
        "multiValued" => false,
        "description" => "Numeric or alphanumeric identifier assigned to a person",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "organization",
        "type" => "string",
        "multiValued" => false,
        "description" => "Identifies the name of an organization",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "division",
        "type" => "string",
        "multiValued" => false,
        "description" => "Identifies the name of a division",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "department",
        "type" => "string",
        "multiValued" => false,
        "description" => "Identifies the name of a department",
        "required" => false,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "manager",
        "type" => "complex",
        "multiValued" => false,
        "description" => "The User's manager",
        "required" => false,
        "subAttributes" => [
          %{
            "name" => "value",
            "type" => "string",
            "multiValued" => false,
            "description" => "The id of the SCIM resource representing the User's manager",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "$ref",
            "type" => "reference",
            "referenceTypes" => ["User"],
            "multiValued" => false,
            "description" => "The URI of the SCIM resource representing the User's manager",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readWrite",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "displayName",
            "type" => "string",
            "multiValued" => false,
            "description" => "The displayName of the User's manager",
            "required" => false,
            "caseExact" => false,
            "mutability" => "readOnly",
            "returned" => "default",
            "uniqueness" => "none"
          }
        ],
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      }
    ],
    "meta" => %{
      "resourceType" => "Schema",
      "location" =>
        "#{base_url()}/scim/v2/Schemas/urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
    }
  }

  @group_schema %{
    "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Schema"],
    "id" => "urn:ietf:params:scim:schemas:core:2.0:Group",
    "name" => "Group",
    "description" => "Group",
    "attributes" => [
      %{
        "name" => "displayName",
        "type" => "string",
        "multiValued" => false,
        "description" => "A human-readable name for the Group",
        "required" => true,
        "caseExact" => false,
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      },
      %{
        "name" => "members",
        "type" => "complex",
        "multiValued" => true,
        "description" => "A list of members of the Group",
        "required" => false,
        "subAttributes" => [
          %{
            "name" => "value",
            "type" => "string",
            "multiValued" => false,
            "description" => "Identifier of the member of this Group",
            "required" => false,
            "caseExact" => false,
            "mutability" => "immutable",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "$ref",
            "type" => "reference",
            "referenceTypes" => ["User", "Group"],
            "multiValued" => false,
            "description" => "The URI corresponding to a SCIM resource that is a member",
            "required" => false,
            "caseExact" => false,
            "mutability" => "immutable",
            "returned" => "default",
            "uniqueness" => "none"
          },
          %{
            "name" => "type",
            "type" => "string",
            "multiValued" => false,
            "description" => "A label indicating the type of resource",
            "required" => false,
            "caseExact" => false,
            "canonicalValues" => ["User", "Group"],
            "mutability" => "immutable",
            "returned" => "default",
            "uniqueness" => "none"
          }
        ],
        "mutability" => "readWrite",
        "returned" => "default",
        "uniqueness" => "none"
      }
    ],
    "meta" => %{
      "resourceType" => "Schema",
      "location" => "#{base_url()}/scim/v2/Schemas/urn:ietf:params:scim:schemas:core:2.0:Group"
    }
  }

  @schemas %{
    "urn:ietf:params:scim:schemas:core:2.0:User" => @user_schema,
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" => @enterprise_user_schema,
    "urn:ietf:params:scim:schemas:core:2.0:Group" => @group_schema
  }

  @impl true
  def get_schema(schema_uri) do
    case Map.get(@schemas, schema_uri) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

  @impl true
  def list_schemas do
    Map.values(@schemas)
  end

  @impl true
  def has_schema?(schema_uri) do
    Map.has_key?(@schemas, schema_uri)
  end

  @doc "Returns the User schema map for testing purposes."
  def get_user_schema, do: @user_schema

  @doc "Returns the EnterpriseUser schema map for testing purposes."
  def get_enterprise_user_schema, do: @enterprise_user_schema

  @doc "Returns the Group schema map for testing purposes."
  def get_group_schema, do: @group_schema
end
