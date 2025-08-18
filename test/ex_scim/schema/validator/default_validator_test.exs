defmodule ExScim.SchemaserResource.Validator.DefaultValidatorTest do
  use ExUnit.Case, async: true

  alias ExScim.Schema.Validator.DefaultValidator

  import ExScim.TestFixtures

  describe "validate_scim_schema/1" do
    test "validates valid SCIM user data successfully" do
      scim_data = valid_scim_user_attrs()

      assert {:ok, validated_data} = DefaultValidator.validate_scim_schema(scim_data)
      assert validated_data == scim_data
    end

    test "requires schemas field" do
      scim_data = %{"userName" => "test.user"}

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :schemas)
    end

    test "requires schemas to be an array" do
      scim_data = %{
        "schemas" => "urn:ietf:params:scim:schemas:core:2.0:User",
        "userName" => "test.user"
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :schemas)
    end

    test "requires a valid SCIM resource schema in schemas array" do
      scim_data = %{
        "schemas" => ["urn:invalid:schema"],
        "userName" => "test.user"
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :schemas)
    end

    test "validates required userName field" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "name" => %{"givenName" => "John", "familyName" => "Doe"}
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :userName)
    end

    test "rejects empty userName" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => ""
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :userName)
    end

    test "validates string field types" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        # Should be string
        "userName" => 12345,
        "displayName" => "John Doe"
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :userName)
    end

    test "validates boolean field types" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        # Should be boolean
        "active" => "true"
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :active)
    end

    test "validates complex field structure for name" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        # Should be object, not string
        "name" => "John Doe"
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :name)
    end

    test "validates multi-valued complex field structure for emails" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        # Should be array
        "emails" => %{"value" => "test@example.com"}
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :emails)
    end

    test "validates canonical values for email type" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "emails" => [
          %{
            "value" => "test@example.com",
            # Should be work, home, or other
            "type" => "invalid"
          }
        ]
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :type)
    end

    test "accepts valid canonical values for email type" do
      for valid_type <- ["work", "home", "other"] do
        scim_data = %{
          "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
          "userName" => "test.user",
          "emails" => [
            %{
              "value" => "test@example.com",
              "type" => valid_type
            }
          ]
        }

        assert {:ok, _validated_data} = DefaultValidator.validate_scim_schema(scim_data)
      end
    end

    test "validates sub-attributes in complex fields" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "name" => %{
          # Should be string
          "givenName" => 123,
          "familyName" => "Doe"
        }
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :"name.givenName")
    end

    test "allows optional fields to be missing" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user"
        # Missing optional fields like displayName, emails, etc.
      }

      assert {:ok, validated_data} = DefaultValidator.validate_scim_schema(scim_data)
      assert validated_data == scim_data
    end

    test "validates Enterprise User extension schema" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"],
        "userName" => "test.user",
        "employeeNumber" => "E12345",
        "manager" => %{
          "value" => "manager-id",
          "displayName" => "Manager Name"
        }
      }

      assert {:ok, validated_data} = DefaultValidator.validate_scim_schema(scim_data)
      assert validated_data == scim_data
    end
  end

  describe "validate_scim_partial/2" do
    test "validates partial data for CREATE operation" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user"
      }

      assert {:ok, validated_data} = DefaultValidator.validate_scim_partial(scim_data, :create)
      assert validated_data == scim_data
    end

    test "validates partial data for UPDATE operation" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "displayName" => "Updated Name"
      }

      assert {:ok, validated_data} = DefaultValidator.validate_scim_partial(scim_data, :update)
      assert validated_data == scim_data
    end

    test "validates partial data for PATCH operation without requiring all fields" do
      # PATCH should not require userName even though it's marked as required in schema
      scim_data = %{
        "displayName" => "Updated Name",
        "active" => false
      }

      assert {:ok, validated_data} = DefaultValidator.validate_scim_partial(scim_data, :patch)
      assert validated_data == scim_data
    end

    test "validates field types in partial PATCH data" do
      scim_data = %{
        # Should be boolean
        "active" => "false"
      }

      assert {:error, errors} = DefaultValidator.validate_scim_partial(scim_data, :patch)
      assert Keyword.has_key?(errors, :active)
    end

    test "validates canonical values in partial PATCH data" do
      scim_data = %{
        "emails" => [
          %{
            "value" => "test@example.com",
            # Should be work, home, or other
            "type" => "invalid"
          }
        ]
      }

      assert {:error, errors} = DefaultValidator.validate_scim_partial(scim_data, :patch)
      assert Keyword.has_key?(errors, :type)
    end
  end

  describe "error handling" do
    test "returns meaningful error messages" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => 123,
        "active" => "false",
        "emails" => [%{"type" => "invalid"}]
      }

      assert {:error, errors} = DefaultValidator.validate_scim_schema(scim_data)

      # Should have specific error messages
      assert {_, error_msg} = List.keyfind(errors, :userName, 0)
      assert String.contains?(error_msg, "string")

      assert {_, error_msg} = List.keyfind(errors, :active, 0)
      assert String.contains?(error_msg, "boolean")

      assert {_, error_msg} = List.keyfind(errors, :type, 0)
      assert String.contains?(error_msg, "work, home, other")
    end
  end
end
