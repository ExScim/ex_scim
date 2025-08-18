defmodule ExScim.Schema.Repository.DefaultRepositoryTest do
  use ExUnit.Case, async: true

  alias ExScim.Schema.Repository.DefaultRepository

  describe "RFC 7643 compliance" do
    test "User schema contains all required core attributes" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]
      attribute_names = Enum.map(attributes, fn attr -> attr["name"] end)

      # Core User attributes from RFC 7643
      assert "userName" in attribute_names
      assert "name" in attribute_names
      assert "displayName" in attribute_names
      assert "emails" in attribute_names
      assert "active" in attribute_names
    end

    test "userName attribute follows RFC 7643 specification" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      username_attr = Enum.find(attributes, fn attr -> attr["name"] == "userName" end)

      # RFC 7643 Section 4.1.1
      assert username_attr["type"] == "string"
      assert username_attr["multiValued"] == false
      assert username_attr["required"] == true
      assert username_attr["caseExact"] == false
      assert username_attr["mutability"] == "readWrite"
      assert username_attr["returned"] == "default"
      assert username_attr["uniqueness"] == "server"
    end

    test "name attribute is complex with correct sub-attributes" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      name_attr = Enum.find(attributes, fn attr -> attr["name"] == "name" end)

      assert name_attr["type"] == "complex"
      assert name_attr["multiValued"] == false
      assert name_attr["required"] == false

      sub_attributes = name_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      assert "formatted" in sub_attr_names
      assert "familyName" in sub_attr_names
      assert "givenName" in sub_attr_names
    end

    test "emails attribute is multi-valued complex with canonical values" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      emails_attr = Enum.find(attributes, fn attr -> attr["name"] == "emails" end)

      assert emails_attr["type"] == "complex"
      assert emails_attr["multiValued"] == true
      assert emails_attr["required"] == false

      sub_attributes = emails_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      assert "value" in sub_attr_names
      assert "display" in sub_attr_names
      assert "type" in sub_attr_names
      assert "primary" in sub_attr_names

      # Check canonical values for type
      type_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "type" end)
      assert type_attr["canonicalValues"] == ["work", "home", "other"]
    end

    test "Enterprise User schema contains manager complex attribute" do
      uri = "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      manager_attr = Enum.find(attributes, fn attr -> attr["name"] == "manager" end)

      assert manager_attr["type"] == "complex"
      assert manager_attr["multiValued"] == false

      sub_attributes = manager_attr["subAttributes"]
      sub_attr_names = Enum.map(sub_attributes, fn attr -> attr["name"] end)

      assert "value" in sub_attr_names
      assert "$ref" in sub_attr_names
      assert "displayName" in sub_attr_names

      # Check that displayName is readOnly
      display_name_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "displayName" end)
      assert display_name_attr["mutability"] == "readOnly"
    end

    test "Group schema contains members with canonical values" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:Group"

      assert {:ok, schema} = DefaultRepository.get_schema(uri)
      attributes = schema["attributes"]

      members_attr = Enum.find(attributes, fn attr -> attr["name"] == "members" end)

      assert members_attr["type"] == "complex"
      assert members_attr["multiValued"] == true

      sub_attributes = members_attr["subAttributes"]
      type_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "type" end)
      assert type_attr["canonicalValues"] == ["User", "Group"]
    end
  end

  describe "schema metadata" do
    test "all schemas have proper meta information" do
      schemas = DefaultRepository.list_schemas()

      for schema <- schemas do
        meta = schema["meta"]
        assert meta["resourceType"] == "Schema"
        assert String.starts_with?(meta["location"], "http://")
        assert String.contains?(meta["location"], "/scim/v2/Schemas/")
        assert String.contains?(meta["location"], schema["id"])
      end
    end
  end
end
