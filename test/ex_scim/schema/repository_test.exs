defmodule ExScim.Schema.RepositoryTest do
  use ExUnit.Case, async: true

  alias ExScim.Schema.Repository

  describe "get_schema/1" do
    test "returns User schema for core User schema URI" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = Repository.get_schema(uri)
      assert schema["id"] == uri
      assert schema["name"] == "User"
      assert schema["description"] == "User Account"
      assert is_list(schema["attributes"])
    end

    test "returns Enterprise User schema for enterprise extension URI" do
      uri = "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

      assert {:ok, schema} = Repository.get_schema(uri)
      assert schema["id"] == uri
      assert schema["name"] == "EnterpriseUser"
      assert schema["description"] == "Enterprise User"
      assert is_list(schema["attributes"])
    end

    test "returns Group schema for core Group schema URI" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:Group"

      assert {:ok, schema} = Repository.get_schema(uri)
      assert schema["id"] == uri
      assert schema["name"] == "Group"
      assert schema["description"] == "Group"
      assert is_list(schema["attributes"])
    end

    test "returns error for unknown schema URI" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:Unknown"

      assert {:error, :not_found} = Repository.get_schema(uri)
    end

    test "User schema has required userName attribute" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = Repository.get_schema(uri)
      attributes = schema["attributes"]

      username_attr = Enum.find(attributes, fn attr -> attr["name"] == "userName" end)
      assert username_attr != nil
      assert username_attr["required"] == true
      assert username_attr["type"] == "string"
      assert username_attr["uniqueness"] == "server"
    end

    test "User schema has emails complex attribute with canonical values" do
      uri = "urn:ietf:params:scim:schemas:core:2.0:User"

      assert {:ok, schema} = Repository.get_schema(uri)
      attributes = schema["attributes"]

      emails_attr = Enum.find(attributes, fn attr -> attr["name"] == "emails" end)
      assert emails_attr != nil
      assert emails_attr["type"] == "complex"
      assert emails_attr["multiValued"] == true

      sub_attributes = emails_attr["subAttributes"]
      type_attr = Enum.find(sub_attributes, fn attr -> attr["name"] == "type" end)
      assert type_attr["canonicalValues"] == ["work", "home", "other"]
    end
  end

  describe "list_schemas/0" do
    test "returns all available schemas" do
      schemas = Repository.list_schemas()

      assert length(schemas) == 3

      schema_ids = Enum.map(schemas, fn schema -> schema["id"] end)
      assert "urn:ietf:params:scim:schemas:core:2.0:User" in schema_ids
      assert "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" in schema_ids
      assert "urn:ietf:params:scim:schemas:core:2.0:Group" in schema_ids
    end

    test "all schemas have required schema structure" do
      schemas = Repository.list_schemas()

      for schema <- schemas do
        assert is_binary(schema["id"])
        assert is_binary(schema["name"])
        assert is_binary(schema["description"])
        assert is_list(schema["attributes"])
        assert schema["schemas"] == ["urn:ietf:params:scim:schemas:core:2.0:Schema"]
        assert is_map(schema["meta"])
        assert schema["meta"]["resourceType"] == "Schema"
      end
    end
  end

  describe "has_schema?/1" do
    test "returns true for existing schema URIs" do
      assert Repository.has_schema?("urn:ietf:params:scim:schemas:core:2.0:User") == true

      assert Repository.has_schema?("urn:ietf:params:scim:schemas:extension:enterprise:2.0:User") ==
               true

      assert Repository.has_schema?("urn:ietf:params:scim:schemas:core:2.0:Group") == true
    end

    test "returns false for non-existing schema URIs" do
      assert Repository.has_schema?("urn:ietf:params:scim:schemas:core:2.0:Unknown") == false
      assert Repository.has_schema?("invalid-uri") == false
      assert Repository.has_schema?("") == false
    end
  end

  describe "adapter configuration" do
    test "uses configured adapter" do
      # The default configuration should use DefaultRepository
      assert Repository.adapter() == ExScim.Schema.Repository.DefaultRepository
    end
  end
end
