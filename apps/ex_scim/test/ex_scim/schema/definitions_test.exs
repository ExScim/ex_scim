defmodule ExScim.Schema.DefinitionsTest do
  @moduledoc """
  Tests that verify DSL-built schemas exactly match the legacy hardcoded schemas.
  """
  use ExUnit.Case, async: true

  alias ExScim.Schema.Repository.LegacyRepository
  alias ExScim.Schema.Definitions.{User, EnterpriseUser, Group}

  # Normalize schema by removing meta.location (which depends on runtime base_url)
  defp normalize(schema) do
    schema
    |> Map.update("meta", %{}, fn meta -> Map.delete(meta, "location") end)
  end

  # Deep sort attributes and sub-attributes for comparison
  defp sort_attributes(schema) do
    schema
    |> Map.update("attributes", [], fn attrs ->
      attrs
      |> Enum.map(&sort_sub_attributes/1)
      |> Enum.sort_by(& &1["name"])
    end)
  end

  defp sort_sub_attributes(attr) do
    case Map.get(attr, "subAttributes") do
      nil ->
        attr

      sub_attrs ->
        sorted_subs = Enum.sort_by(sub_attrs, & &1["name"])
        Map.put(attr, "subAttributes", sorted_subs)
    end
  end

  describe "User schema DSL matches legacy" do
    test "schema id matches" do
      assert User.schema_id() == "urn:ietf:params:scim:schemas:core:2.0:User"
    end

    test "top-level schema structure matches" do
      dsl_schema = User.to_map()
      legacy_schema = LegacyRepository.get_user_schema()

      assert dsl_schema["schemas"] == legacy_schema["schemas"]
      assert dsl_schema["id"] == legacy_schema["id"]
      assert dsl_schema["name"] == legacy_schema["name"]
      assert dsl_schema["description"] == legacy_schema["description"]
    end

    test "attribute count matches" do
      dsl_schema = User.to_map()
      legacy_schema = LegacyRepository.get_user_schema()

      assert length(dsl_schema["attributes"]) == length(legacy_schema["attributes"])
    end

    test "userName attribute matches exactly" do
      dsl_schema = User.to_map()
      legacy_schema = LegacyRepository.get_user_schema()

      dsl_attr = find_attribute(dsl_schema, "userName")
      legacy_attr = find_attribute(legacy_schema, "userName")

      assert dsl_attr == legacy_attr
    end

    test "name complex attribute matches exactly" do
      dsl_schema = User.to_map()
      legacy_schema = LegacyRepository.get_user_schema()

      dsl_attr = find_attribute(dsl_schema, "name") |> sort_sub_attributes()
      legacy_attr = find_attribute(legacy_schema, "name") |> sort_sub_attributes()

      assert dsl_attr == legacy_attr
    end

    test "emails complex attribute matches exactly" do
      dsl_schema = User.to_map()
      legacy_schema = LegacyRepository.get_user_schema()

      dsl_attr = find_attribute(dsl_schema, "emails") |> sort_sub_attributes()
      legacy_attr = find_attribute(legacy_schema, "emails") |> sort_sub_attributes()

      assert dsl_attr == legacy_attr
    end

    test "active boolean attribute matches (no uniqueness key)" do
      dsl_schema = User.to_map()
      legacy_schema = LegacyRepository.get_user_schema()

      dsl_attr = find_attribute(dsl_schema, "active")
      legacy_attr = find_attribute(legacy_schema, "active")

      # active should NOT have uniqueness key
      refute Map.has_key?(legacy_attr, "uniqueness")
      assert dsl_attr == legacy_attr
    end

    test "photos attribute matches (with reference sub-attribute)" do
      dsl_schema = User.to_map()
      legacy_schema = LegacyRepository.get_user_schema()

      dsl_attr = find_attribute(dsl_schema, "photos") |> sort_sub_attributes()
      legacy_attr = find_attribute(legacy_schema, "photos") |> sort_sub_attributes()

      assert dsl_attr == legacy_attr
    end

    test "complete schema matches when normalized" do
      dsl_schema = User.to_map() |> normalize() |> sort_attributes()
      legacy_schema = LegacyRepository.get_user_schema() |> normalize() |> sort_attributes()

      assert dsl_schema == legacy_schema
    end
  end

  describe "EnterpriseUser schema DSL matches legacy" do
    test "schema id matches" do
      assert EnterpriseUser.schema_id() ==
               "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
    end

    test "top-level schema structure matches" do
      dsl_schema = EnterpriseUser.to_map()
      legacy_schema = LegacyRepository.get_enterprise_user_schema()

      assert dsl_schema["schemas"] == legacy_schema["schemas"]
      assert dsl_schema["id"] == legacy_schema["id"]
      assert dsl_schema["name"] == legacy_schema["name"]
      assert dsl_schema["description"] == legacy_schema["description"]
    end

    test "manager complex attribute matches exactly" do
      dsl_schema = EnterpriseUser.to_map()
      legacy_schema = LegacyRepository.get_enterprise_user_schema()

      dsl_attr = find_attribute(dsl_schema, "manager") |> sort_sub_attributes()
      legacy_attr = find_attribute(legacy_schema, "manager") |> sort_sub_attributes()

      assert dsl_attr == legacy_attr
    end

    test "manager.$ref reference attribute matches" do
      dsl_schema = EnterpriseUser.to_map()
      legacy_schema = LegacyRepository.get_enterprise_user_schema()

      dsl_manager = find_attribute(dsl_schema, "manager")
      legacy_manager = find_attribute(legacy_schema, "manager")

      dsl_ref = find_sub_attribute(dsl_manager, "$ref")
      legacy_ref = find_sub_attribute(legacy_manager, "$ref")

      assert dsl_ref == legacy_ref
    end

    test "complete schema matches when normalized" do
      dsl_schema = EnterpriseUser.to_map() |> normalize() |> sort_attributes()
      legacy_schema = LegacyRepository.get_enterprise_user_schema() |> normalize() |> sort_attributes()

      assert dsl_schema == legacy_schema
    end
  end

  describe "Group schema DSL matches legacy" do
    test "schema id matches" do
      assert Group.schema_id() == "urn:ietf:params:scim:schemas:core:2.0:Group"
    end

    test "top-level schema structure matches" do
      dsl_schema = Group.to_map()
      legacy_schema = LegacyRepository.get_group_schema()

      assert dsl_schema["schemas"] == legacy_schema["schemas"]
      assert dsl_schema["id"] == legacy_schema["id"]
      assert dsl_schema["name"] == legacy_schema["name"]
      assert dsl_schema["description"] == legacy_schema["description"]
    end

    test "displayName attribute matches (required: true)" do
      dsl_schema = Group.to_map()
      legacy_schema = LegacyRepository.get_group_schema()

      dsl_attr = find_attribute(dsl_schema, "displayName")
      legacy_attr = find_attribute(legacy_schema, "displayName")

      assert dsl_attr == legacy_attr
    end

    test "members complex attribute matches exactly" do
      dsl_schema = Group.to_map()
      legacy_schema = LegacyRepository.get_group_schema()

      dsl_attr = find_attribute(dsl_schema, "members") |> sort_sub_attributes()
      legacy_attr = find_attribute(legacy_schema, "members") |> sort_sub_attributes()

      assert dsl_attr == legacy_attr
    end

    test "members.$ref has immutable mutability" do
      dsl_schema = Group.to_map()
      legacy_schema = LegacyRepository.get_group_schema()

      dsl_members = find_attribute(dsl_schema, "members")
      legacy_members = find_attribute(legacy_schema, "members")

      dsl_ref = find_sub_attribute(dsl_members, "$ref")
      legacy_ref = find_sub_attribute(legacy_members, "$ref")

      assert dsl_ref["mutability"] == "immutable"
      assert dsl_ref == legacy_ref
    end

    test "complete schema matches when normalized" do
      dsl_schema = Group.to_map() |> normalize() |> sort_attributes()
      legacy_schema = LegacyRepository.get_group_schema() |> normalize() |> sort_attributes()

      assert dsl_schema == legacy_schema
    end
  end

  # Helper to find an attribute by name
  defp find_attribute(schema, name) do
    Enum.find(schema["attributes"], fn attr -> attr["name"] == name end)
  end

  # Helper to find a sub-attribute by name
  defp find_sub_attribute(attribute, name) do
    Enum.find(attribute["subAttributes"], fn attr -> attr["name"] == name end)
  end
end
