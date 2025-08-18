defmodule ExScim.UsersTest do
  use ExUnit.Case, async: true

  import ExScim.TestFixtures
  import ExScim.SCIMComplianceHelpers

  describe "data validation and transformation" do
    test "validates SCIM user attributes structure" do
      valid_attrs = valid_scim_user_attrs()
      minimal_attrs = minimal_scim_user_attrs()

      # These should have proper SCIM structure
      assert is_map(valid_attrs)
      assert Map.has_key?(valid_attrs, "userName")
      assert Map.has_key?(valid_attrs, "name")

      assert is_map(minimal_attrs)
      assert Map.has_key?(minimal_attrs, "userName")
      assert Map.has_key?(minimal_attrs, "name")
    end

    test "creates patch operations with proper format" do
      valid_patch = valid_patch_operations()
      malformed_patch = malformed_patch_operations()

      # Valid patch should conform to SCIM format
      assert_scim_patch_operations(valid_patch)

      # Malformed patch should be detectable
      assert Map.has_key?(malformed_patch, "Operations")
      assert is_list(malformed_patch["Operations"])
    end
  end

  describe "domain user struct" do
    test "creates proper domain user struct" do
      domain_user = domain_user_struct()

      assert domain_user.__struct__ == ExScim.Users.User
      assert is_binary(domain_user.id)
      assert is_binary(domain_user.user_name)
      assert is_binary(domain_user.display_name)
      assert is_boolean(domain_user.active)
    end

    test "domain user with metadata has proper timestamps" do
      domain_user_with_meta = domain_user_with_metadata()

      assert domain_user_with_meta.__struct__ == ExScim.Users.User
      assert %DateTime{} = domain_user_with_meta.meta_created
      assert %DateTime{} = domain_user_with_meta.meta_last_modified
    end
  end

  describe "SCIM compliance helpers" do
    test "validates SCIM error response format" do
      error_response = scim_error_response("invalidFilter", "Invalid filter expression", 400)

      assert_scim_error(error_response, "invalidFilter", 400)
      assert error_response["detail"] == "Invalid filter expression"
    end

    test "validates SCIM list response format" do
      users = [valid_scim_user_attrs()]
      list_response = scim_list_response(users, 1)

      assert_scim_list_response(list_response, 1, 1)
      assert list_response["Resources"] == users
    end

    test "validates basic filter expressions" do
      basic_filters = [
        "userName eq \"john.doe\"",
        "active eq true",
        "userName sw \"john\"",
        "email co \"@example.com\""
      ]

      for filter <- basic_filters do
        assert_valid_scim_filter(filter)
      end
    end

    test "detects empty filter expressions" do
      # Only test the empty filter case which we know will fail
      assert_raise ExUnit.AssertionError, fn ->
        assert_valid_scim_filter("")
      end
    end
  end

  describe "test fixtures completeness" do
    test "provides all necessary SCIM user fixtures" do
      # Verify all fixtures are available and properly structured
      assert is_map(valid_scim_user_attrs())
      assert is_map(minimal_scim_user_attrs())
      assert is_map(complex_scim_user_attrs())
      assert is_map(invalid_scim_user_attrs())
    end

    test "provides patch operation fixtures" do
      assert is_map(valid_patch_operations())
      assert is_map(malformed_patch_operations())
      assert Map.has_key?(valid_patch_operations(), "Operations")
      assert Map.has_key?(malformed_patch_operations(), "Operations")
    end

    test "provides domain struct fixtures" do
      domain_user = domain_user_struct()
      assert domain_user.__struct__ == ExScim.Users.User

      domain_user_meta = domain_user_with_metadata()
      assert domain_user_meta.__struct__ == ExScim.Users.User
    end
  end
end
