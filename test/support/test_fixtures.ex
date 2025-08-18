defmodule ExScim.TestFixtures do
  @moduledoc """
  Test fixtures for SCIM data and domain structs.
  """

  @doc """
  Generate valid SCIM user data with all standard attributes.
  """
  def valid_scim_user_attrs do
    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName" => "john.doe",
      "name" => %{
        "givenName" => "John",
        "familyName" => "Doe",
        "formatted" => "John Doe"
      },
      "displayName" => "John Doe",
      "emails" => [
        %{
          "value" => "john.doe@example.com",
          "type" => "work",
          "primary" => true
        },
        %{
          "value" => "john@personal.com",
          "type" => "home",
          "primary" => false
        }
      ],
      "phoneNumbers" => [
        %{
          "value" => "+1-555-0123",
          "type" => "work"
        }
      ],
      "active" => true,
      "externalId" => "external-123"
    }
  end

  @doc """
  Generate minimal valid SCIM user data with only required fields.
  """
  def minimal_scim_user_attrs do
    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName" => "jane.smith",
      "name" => %{
        "givenName" => "Jane",
        "familyName" => "Smith"
      }
    }
  end

  @doc """
  Generate complex SCIM user data with nested structures and edge cases.
  """
  def complex_scim_user_attrs do
    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName" => "complex.user",
      "name" => %{
        "givenName" => "Complex",
        "familyName" => "User",
        "middleName" => "Test",
        "honorificPrefix" => "Dr.",
        "honorificSuffix" => "Jr."
      },
      "displayName" => "Dr. Complex Test User Jr.",
      "nickName" => "Comp",
      "profileUrl" => "https://example.com/profile/complex",
      "title" => "Senior Engineer",
      "userType" => "Employee",
      "preferredLanguage" => "en-US",
      "locale" => "en_US",
      "timezone" => "America/Los_Angeles",
      "emails" => [
        %{"value" => "complex@work.com", "type" => "work", "primary" => true},
        %{"value" => "complex@home.com", "type" => "home"},
        %{"value" => "complex@other.com", "type" => "other"}
      ],
      "phoneNumbers" => [
        %{"value" => "+1-555-0199", "type" => "work"},
        %{"value" => "+1-555-0299", "type" => "home"},
        %{"value" => "+1-555-0399", "type" => "mobile"}
      ],
      "ims" => [
        %{"value" => "complex_skype", "type" => "skype"},
        %{"value" => "complex_aim", "type" => "aim"}
      ],
      "photos" => [
        %{"value" => "https://example.com/photo.jpg", "type" => "photo"}
      ],
      "addresses" => [
        %{
          "type" => "work",
          "streetAddress" => "123 Main St",
          "locality" => "Anytown",
          "region" => "CA",
          "postalCode" => "12345",
          "country" => "US",
          "formatted" => "123 Main St\nAnytown, CA 12345 US",
          "primary" => true
        }
      ],
      "groups" => [
        %{"value" => "group-123", "display" => "Developers"},
        %{"value" => "group-456", "display" => "Managers"}
      ],
      "entitlements" => [
        %{"value" => "admin", "type" => "role"},
        %{"value" => "developer", "type" => "role"}
      ],
      "roles" => [
        %{"value" => "Engineer", "primary" => true}
      ],
      "x509Certificates" => [
        %{"value" => "MIICert..."}
      ],
      "active" => true,
      "externalId" => "complex-external-123"
    }
  end

  @doc """
  Generate invalid SCIM user data for error testing.
  """
  def invalid_scim_user_attrs do
    %{
      # Required field is nil
      "userName" => nil,
      # Should be object
      "name" => "invalid_string",
      # Should be array
      "emails" => "not_an_array",
      # Should be boolean
      "active" => "not_boolean",
      "invalidField" => "should_not_exist"
    }
  end

  @doc """
  Generate malformed PATCH operations for error testing.
  """
  def malformed_patch_operations do
    %{
      "Operations" => [
        %{
          "op" => "invalid_op",
          "path" => "userName",
          "value" => "new_value"
        },
        %{
          "op" => "replace",
          # Invalid path
          "path" => nil,
          "value" => "value"
        },
        %{
          "op" => "add"
          # Missing required fields
        }
      ]
    }
  end

  @doc """
  Generate valid PATCH operations for testing.
  """
  def valid_patch_operations do
    %{
      "Operations" => [
        %{
          "op" => "replace",
          "path" => "displayName",
          "value" => "Updated Name"
        },
        %{
          "op" => "add",
          "path" => "emails",
          "value" => %{
            "value" => "new@example.com",
            "type" => "work"
          }
        },
        %{
          "op" => "remove",
          "path" => "phoneNumbers[type eq \"mobile\"]"
        }
      ]
    }
  end

  @doc """
  Generate domain user struct (ExScim.Users.User format).
  """
  def domain_user_struct do
    %ExScim.Users.User{
      id: "550e8400-e29b-41d4-a716-446655440000",
      user_name: "domain.user",
      display_name: "Domain User",
      active: true,
      external_id: "domain-ext-123",
      meta_created: ~U[2024-01-01 12:00:00Z],
      meta_last_modified: ~U[2024-01-01 12:00:00Z]
    }
  end

  @doc """
  Generate domain user struct with metadata.
  """
  def domain_user_with_metadata do
    %{
      domain_user_struct()
      | meta_created: ~U[2024-01-01 10:00:00Z],
        meta_last_modified: ~U[2024-01-01 15:30:00Z]
    }
  end

  @doc """
  Generate SCIM filter expressions for testing.
  """
  def scim_filter_expressions do
    [
      # Simple equality
      "userName eq \"john.doe\"",
      # String operations
      "userName sw \"john\"",
      "userName co \"doe\"",
      "userName ew \".com\"",
      # Boolean
      "active eq true",
      # Date comparison
      "meta.created gt \"2024-01-01T00:00:00Z\"",
      # Complex expressions
      "userName sw \"john\" and active eq true",
      "emails[type eq \"work\" and primary eq true].value co \"@company.com\"",
      # Presence
      "title pr",
      # Logical operators
      "userName eq \"john\" or userName eq \"jane\"",
      "(userName eq \"john\" or userName eq \"jane\") and active eq true"
    ]
  end

  @doc """
  Generate invalid SCIM filter expressions for error testing.
  """
  def invalid_scim_filter_expressions do
    [
      "userName invalid_operator \"value\"",
      # Missing value
      "userName eq",
      # Missing attribute
      "eq \"value\"",
      "userName eq \"unclosed_quote",
      "((unbalanced_parentheses",
      # Incomplete expression
      "userName eq true and",
      # Empty filter
      ""
    ]
  end

  @doc """
  Generate SCIM list response structure.
  """
  def scim_list_response(resources, total \\ nil) do
    %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
      "totalResults" => total || length(resources),
      "startIndex" => 1,
      "itemsPerPage" => length(resources),
      "Resources" => resources
    }
  end

  @doc """
  Generate SCIM error response structure.
  """
  def scim_error_response(scim_type, detail, status \\ 400) do
    %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "scimType" => scim_type,
      "detail" => detail,
      "status" => to_string(status)
    }
  end
end
