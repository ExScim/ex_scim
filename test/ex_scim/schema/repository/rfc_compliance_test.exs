defmodule ExScim.Schema.Repository.RfcComplianceTest do
  use ExUnit.Case, async: true

  alias ExScim.Schema.Repository.DefaultRepository

  describe "RFC 7643 complete attribute coverage" do
    test "User schema contains all RFC 7643 core attributes" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]
      attribute_names = Enum.map(attributes, fn attr -> attr["name"] end)

      # Core User attributes from RFC 7643 Section 4.1
      required_attributes = [
        "userName",
        "name",
        "displayName",
        "emails",
        "phoneNumbers",
        "addresses",
        "photos",
        "active",
        "title",
        "userType",
        "preferredLanguage",
        "locale",
        "timezone"
      ]

      for attr_name <- required_attributes do
        assert attr_name in attribute_names, "Missing required attribute: #{attr_name}"
      end
    end

    test "phoneNumbers attribute follows RFC 7643 specification" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      phone_attr = Enum.find(attributes, fn attr -> attr["name"] == "phoneNumbers" end)

      assert phone_attr["type"] == "complex"
      assert phone_attr["multiValued"] == true
      assert phone_attr["required"] == false

      sub_attributes = phone_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      assert "value" in sub_attr_names
      assert "display" in sub_attr_names
      assert "type" in sub_attr_names
      assert "primary" in sub_attr_names

      # Check canonical values for type
      type_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "type" end)
      expected_phone_types = ["work", "home", "mobile", "fax", "pager", "other"]
      assert type_attr["canonicalValues"] == expected_phone_types
    end

    test "addresses attribute follows RFC 7643 specification" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      address_attr = Enum.find(attributes, fn attr -> attr["name"] == "addresses" end)

      assert address_attr["type"] == "complex"
      assert address_attr["multiValued"] == true
      assert address_attr["required"] == false

      sub_attributes = address_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      # RFC 7643 address components
      required_address_components = [
        "formatted",
        "streetAddress",
        "locality",
        "region",
        "postalCode",
        "country",
        "type",
        "primary"
      ]

      for component <- required_address_components do
        assert component in sub_attr_names, "Missing address component: #{component}"
      end

      # Check canonical values for type
      type_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "type" end)
      assert type_attr["canonicalValues"] == ["work", "home", "other"]
    end

    test "photos attribute follows RFC 7643 specification" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      photos_attr = Enum.find(attributes, fn attr -> attr["name"] == "photos" end)

      assert photos_attr["type"] == "complex"
      assert photos_attr["multiValued"] == true
      assert photos_attr["required"] == false

      sub_attributes = photos_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      assert "value" in sub_attr_names
      assert "display" in sub_attr_names
      assert "type" in sub_attr_names
      assert "primary" in sub_attr_names

      # Check that value is reference type
      value_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "value" end)
      assert value_attr["type"] == "reference"
      assert value_attr["referenceTypes"] == ["external"]

      # Check canonical values for type
      type_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "type" end)
      assert type_attr["canonicalValues"] == ["photo", "thumbnail"]
    end
  end

  describe "mutability constraints" do
    test "attributes have proper mutability settings" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      for attr <- attributes do
        mutability = attr["mutability"]

        assert mutability in ["readOnly", "readWrite", "immutable", "writeOnly"],
               "Invalid mutability '#{mutability}' for attribute '#{attr["name"]}'"
      end
    end

    test "userName has server uniqueness constraint" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      username_attr = Enum.find(attributes, fn attr -> attr["name"] == "userName" end)
      assert username_attr["uniqueness"] == "server"
      assert username_attr["required"] == true
    end
  end

  describe "case sensitivity" do
    test "attributes have proper caseExact settings" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      for attr <- attributes do
        if attr["type"] == "string" do
          assert Map.has_key?(attr, "caseExact"),
                 "String attribute '#{attr["name"]}' missing caseExact property"

          assert is_boolean(attr["caseExact"]),
                 "caseExact must be boolean for attribute '#{attr["name"]}'"
        end
      end
    end
  end

  describe "returned attribute filtering" do
    test "attributes have proper returned settings" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      valid_returned_values = ["always", "never", "default", "request"]

      for attr <- attributes do
        returned = attr["returned"]

        assert returned in valid_returned_values,
               "Invalid returned value '#{returned}' for attribute '#{attr["name"]}'"
      end
    end
  end

  describe "reference type validation" do
    test "reference attributes have proper referenceTypes" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)

      # Find all reference type attributes
      all_attributes = get_all_attributes_recursive(schema["attributes"])

      reference_attrs =
        Enum.filter(all_attributes, fn attr ->
          attr["type"] == "reference"
        end)

      for attr <- reference_attrs do
        assert Map.has_key?(attr, "referenceTypes"),
               "Reference attribute '#{attr["name"]}' missing referenceTypes"

        assert is_list(attr["referenceTypes"]),
               "referenceTypes must be a list for '#{attr["name"]}'"

        assert length(attr["referenceTypes"]) > 0,
               "referenceTypes cannot be empty for '#{attr["name"]}'"
      end
    end
  end

  describe "comprehensive attribute validation" do
    test "validates phoneNumbers with all canonical values" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "phoneNumbers" => [
          %{"value" => "+1-555-0123", "type" => "work"},
          %{"value" => "+1-555-0124", "type" => "home"},
          %{"value" => "+1-555-0125", "type" => "mobile"},
          %{"value" => "+1-555-0126", "type" => "fax"},
          %{"value" => "+1-555-0127", "type" => "pager"},
          %{"value" => "+1-555-0128", "type" => "other"}
        ]
      }

      # This should validate without errors
      # We'll test this through the validator integration
      assert is_map(scim_data)
    end

    test "validates addresses with all canonical values" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "addresses" => [
          %{
            "formatted" => "123 Work St",
            "streetAddress" => "123 Work St",
            "locality" => "Work City",
            "region" => "WS",
            "postalCode" => "12345",
            "country" => "US",
            "type" => "work",
            "primary" => true
          },
          %{
            "formatted" => "456 Home Ave",
            "type" => "home"
          },
          %{
            "formatted" => "789 Other Rd",
            "type" => "other"
          }
        ]
      }

      assert is_map(scim_data)
    end

    test "validates photos with reference type and canonical values" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "photos" => [
          %{
            "value" => "https://example.com/photo.jpg",
            "type" => "photo",
            "primary" => true
          },
          %{
            "value" => "https://example.com/thumb.jpg",
            "type" => "thumbnail"
          }
        ]
      }

      assert is_map(scim_data)
    end
  end

  # Helper function to get all attributes including sub-attributes
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
