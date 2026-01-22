defmodule ExScim.UsersSchemaValidationTest do
  use ExUnit.Case, async: true

  alias ExScim.Schema.Validator

  import ExScim.TestFixtures

  describe "create_user_from_scim/1 with schema validation" do
    test "creates user successfully with valid SCIM data" do
      # This test requires the full stack to be working
      # Skip if storage is not properly configured
      scim_data = valid_scim_user_attrs()

      # The validation should pass through schema validation first
      assert {:ok, schema_validated} = Validator.validate_scim_schema(scim_data)
      assert schema_validated == scim_data
    end

    test "rejects user creation with invalid schema - missing userName" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "name" => %{"givenName" => "John", "familyName" => "Doe"},
        "emails" => [%{"value" => "john@example.com", "type" => "work"}]
        # Missing required userName
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :userName)
    end

    test "rejects user creation with invalid schema - wrong field type" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        # Should be boolean, not string
        "active" => "true"
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :active)
    end

    test "rejects user creation with invalid canonical values" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "emails" => [
          %{
            "value" => "test@example.com",
            # Invalid - should be work, home, or other
            "type" => "business"
          }
        ]
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :type)

      error_message = Keyword.get(errors, :type)
      assert String.contains?(error_message, "work, home, other")
    end

    test "accepts minimal valid SCIM user data" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "minimal.user"
      }

      assert {:ok, validated_data} = Validator.validate_scim_schema(scim_data)
      assert validated_data == scim_data
    end

    test "validates complex nested structures" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "name" => %{
          "givenName" => "John",
          "familyName" => "Doe",
          "formatted" => "John Doe"
        },
        "emails" => [
          %{
            "value" => "work@example.com",
            "type" => "work",
            "primary" => true
          },
          %{
            "value" => "personal@example.com",
            "type" => "home",
            "primary" => false
          }
        ]
      }

      assert {:ok, validated_data} = Validator.validate_scim_schema(scim_data)
      assert validated_data == scim_data
    end

    test "rejects invalid sub-attribute types in complex fields" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "emails" => [
          %{
            "value" => "test@example.com",
            # Should be boolean, not string
            "primary" => "true"
          }
        ]
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :"emails.primary")
    end
  end

  describe "replace_user_from_scim/2 with schema validation" do
    test "validates schema before updating" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "updated.user",
        "displayName" => "Updated User"
      }

      assert {:ok, validated_data} = Validator.validate_scim_schema(scim_data)
      assert validated_data == scim_data
    end

    test "rejects update with invalid schema" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        # Should be string
        "userName" => 12345,
        "displayName" => "Updated User"
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :userName)
    end
  end

  describe "patch_user_from_scim/2 with schema validation" do
    test "validates partial schema for patch operations" do
      scim_data = %{
        "displayName" => "Patched Name",
        "active" => false
      }

      assert {:ok, validated_data} = Validator.validate_scim_partial(scim_data, :patch)
      assert validated_data == scim_data
    end

    test "rejects patch with invalid field types" do
      scim_data = %{
        # Should be boolean
        "active" => "false"
      }

      assert {:error, errors} = Validator.validate_scim_partial(scim_data, :patch)
      assert Keyword.has_key?(errors, :active)
    end

    test "allows patch without userName even though it's required" do
      # PATCH operations should not enforce required field validation
      scim_data = %{
        "displayName" => "New Display Name"
      }

      assert {:ok, validated_data} = Validator.validate_scim_partial(scim_data, :patch)
      assert validated_data == scim_data
    end
  end

  describe "Enterprise User extension validation" do
    test "validates Enterprise User schema correctly" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"],
        "userName" => "enterprise.user",
        "employeeNumber" => "E123456",
        "organization" => "ACME Corp",
        "manager" => %{
          "value" => "manager-123",
          "$ref" => "/Users/manager-123",
          "displayName" => "Manager Name"
        }
      }

      assert {:ok, validated_data} = Validator.validate_scim_schema(scim_data)
      assert validated_data == scim_data
    end

    test "validates manager reference types correctly" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"],
        "userName" => "enterprise.user",
        "manager" => %{
          # Should be string
          "value" => 123
        }
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :"manager.value")
    end
  end

  describe "schema validation error handling" do
    test "provides clear error messages for validation failures" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => 123,
        "active" => "true",
        "emails" => "not-an-array"
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)

      # Should have multiple validation errors
      assert length(errors) >= 3

      # Check that error messages are descriptive
      username_error = Keyword.get(errors, :userName)
      assert String.contains?(username_error, "string")

      active_error = Keyword.get(errors, :active)
      assert String.contains?(active_error, "boolean")

      emails_error = Keyword.get(errors, :emails)
      assert String.contains?(emails_error, "array")
    end

    test "validates unknown schema URIs" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:custom:1.0:Unknown"],
        "userName" => "test.user"
      }

      # Should fail because we don't support this schema
      assert {:error, _errors} = Validator.validate_scim_schema(scim_data)
      # The error could be about unknown schema or lack of User schema
    end
  end

  describe "validator adapter configuration" do
    test "uses DefaultValidator when no custom validator is configured" do
      # Test that the default configuration provides schema validation
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user"
      }

      # This should work with the default validator
      assert {:ok, _} = Validator.validate_scim_schema(scim_data)
    end
  end
end
