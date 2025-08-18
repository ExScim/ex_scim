defmodule ExScim.Schema.ProtocolComplianceTest do
  use ExUnit.Case, async: true

  alias ExScim.Schema.Validator
  alias ExScim.Schema.Repository.DefaultRepository

  describe "RFC 7644 uniqueness constraints" do
    test "userName has server uniqueness constraint" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      username_attr = Enum.find(attributes, fn attr -> attr["name"] == "userName" end)
      assert username_attr["uniqueness"] == "server"
      assert username_attr["required"] == true
    end

    test "validates uniqueness constraint values are valid" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      valid_uniqueness_values = ["none", "server", "global"]

      for attr <- attributes do
        uniqueness = attr["uniqueness"]

        if uniqueness do
          assert uniqueness in valid_uniqueness_values,
                 "Invalid uniqueness value '#{uniqueness}' for attribute '#{attr["name"]}'"
        end
      end
    end
  end

  describe "caseExact handling" do
    test "string attributes have caseExact property" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)

      # Get all attributes including sub-attributes
      all_attributes = get_all_attributes_recursive(schema["attributes"])

      string_attributes =
        Enum.filter(all_attributes, fn attr ->
          attr["type"] == "string"
        end)

      for attr <- string_attributes do
        assert Map.has_key?(attr, "caseExact"),
               "String attribute '#{attr["name"]}' missing caseExact property"

        assert is_boolean(attr["caseExact"]),
               "caseExact must be boolean for attribute '#{attr["name"]}'"
      end
    end

    test "userName is case-insensitive (caseExact = false)" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      username_attr = Enum.find(attributes, fn attr -> attr["name"] == "userName" end)
      assert username_attr["caseExact"] == false
    end
  end

  describe "multiValued attributes" do
    test "emails, phoneNumbers, addresses, and photos are multiValued" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      multi_valued_attrs = ["emails", "phoneNumbers", "addresses", "photos"]

      for attr_name <- multi_valued_attrs do
        attr = Enum.find(attributes, fn attr -> attr["name"] == attr_name end)
        assert attr, "Missing #{attr_name} attribute in schema"
        assert attr["multiValued"] == true, "#{attr_name} should be multiValued"
        assert attr["type"] == "complex", "#{attr_name} should be complex type"
      end
    end

    test "validates multiValued complex attributes correctly" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        # This is correctly an array
        "emails" => [
          %{"value" => "test1@example.com", "type" => "work"},
          %{"value" => "test2@example.com", "type" => "home"}
        ]
      }

      assert {:ok, _validated} = Validator.validate_scim_schema(scim_data)
    end

    test "rejects non-array values for multiValued attributes" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        # Should be array, not object
        "emails" => %{"value" => "test@example.com"}
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :emails)

      error_message = Keyword.get(errors, :emails)
      assert String.contains?(error_message, "array")
    end
  end

  describe "primary attribute handling" do
    test "complex multiValued attributes have primary sub-attribute" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      multi_valued_complex_attrs = ["emails", "phoneNumbers", "addresses", "photos"]

      for attr_name <- multi_valued_complex_attrs do
        attr = Enum.find(attributes, fn attr -> attr["name"] == attr_name end)
        sub_attributes = attr["subAttributes"] || []

        primary_attr =
          Enum.find(sub_attributes, fn sub_attr ->
            sub_attr["name"] == "primary"
          end)

        assert primary_attr, "#{attr_name} missing primary sub-attribute"
        assert primary_attr["type"] == "boolean", "primary must be boolean"
        assert primary_attr["required"] == false, "primary should not be required"
      end
    end

    test "validates primary attribute as boolean" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "emails" => [
          %{
            "value" => "test@example.com",
            "type" => "work",
            # Should be boolean, not string
            "primary" => "true"
          }
        ]
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :"emails.primary")
    end
  end

  describe "meta attributes (common attributes)" do
    test "all resources should support meta attributes conceptually" do
      # While meta attributes are typically added by the server,
      # the schema should be compatible with their addition

      # Test that our validation doesn't break with meta attributes
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        # Meta attributes would be added by server, but testing compatibility
        "meta" => %{
          "resourceType" => "User",
          "created" => "2024-01-01T12:00:00.000Z",
          "lastModified" => "2024-01-01T12:00:00.000Z",
          "location" => "https://example.com/v2/Users/123",
          "version" => "W/\"123456789\""
        }
      }

      # Should pass validation (meta is not in core schema but should be ignored)
      assert {:ok, _validated} = Validator.validate_scim_schema(scim_data)
    end
  end

  describe "enterprise user extension" do
    test "enterprise user schema has proper structure" do
      uri = "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)

      assert schema["name"] == "EnterpriseUser"
      assert schema["description"] == "Enterprise User"

      attributes = schema["attributes"]
      attribute_names = Enum.map(attributes, fn attr -> attr["name"] end)

      expected_attrs = ["employeeNumber", "organization", "division", "department", "manager"]

      for attr_name <- expected_attrs do
        assert attr_name in attribute_names, "Missing enterprise attribute: #{attr_name}"
      end
    end

    test "manager attribute has proper reference structure" do
      uri = "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      manager_attr = Enum.find(attributes, fn attr -> attr["name"] == "manager" end)
      assert manager_attr["type"] == "complex"

      sub_attributes = manager_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      assert "value" in sub_attr_names
      assert "$ref" in sub_attr_names
      assert "displayName" in sub_attr_names

      # Check $ref is reference type with proper referenceTypes
      ref_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "$ref" end)
      assert ref_attr["type"] == "reference"
      assert ref_attr["referenceTypes"] == ["User"]
    end
  end

  describe "group schema compliance" do
    test "group schema has proper structure" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:Group"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)

      assert schema["name"] == "Group"
      assert schema["description"] == "Group"

      attributes = schema["attributes"]
      attribute_names = Enum.map(attributes, fn attr -> attr["name"] end)

      assert "displayName" in attribute_names
      assert "members" in attribute_names
    end

    test "group members attribute structure" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:Group"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      members_attr = Enum.find(attributes, fn attr -> attr["name"] == "members" end)
      assert members_attr["type"] == "complex"
      assert members_attr["multiValued"] == true

      sub_attributes = members_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      assert "value" in sub_attr_names
      assert "$ref" in sub_attr_names
      assert "type" in sub_attr_names

      # Check type has proper canonical values
      type_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "type" end)
      assert type_attr["canonicalValues"] == ["User", "Group"]

      # Check $ref supports both User and Group references
      ref_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "$ref" end)
      assert ref_attr["referenceTypes"] == ["User", "Group"]
    end
  end

  # Helper function to get all attributes including sub-attributes recursively
  defp get_all_attributes_recursive(attributes) do
    Enum.reduce(attributes, [], fn attr, acc ->
      sub_attrs =
        case attr["subAttributes"] do
          nil -> []
          sub_attrs -> get_all_attributes_recursive(sub_attrs)
        end

      [attr | sub_attrs] ++ acc
    end)
  end
end
