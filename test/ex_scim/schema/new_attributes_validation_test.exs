defmodule ExScim.Schema.NewAttributesValidationTest do
  use ExUnit.Case, async: true

  alias ExScim.Schema.Validator

  describe "phoneNumbers validation" do
    test "accepts all valid phoneNumbers canonical values" do
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

      assert {:ok, _validated} = Validator.validate_scim_schema(scim_data)
    end

    test "rejects invalid phoneNumbers type" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "phoneNumbers" => [
          %{"value" => "+1-555-0123", "type" => "invalid"}
        ]
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :type)

      error_message = Keyword.get(errors, :type)
      assert String.contains?(error_message, "work, home, mobile, fax, pager, other")
    end

    test "validates phoneNumbers structure correctly" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "phoneNumbers" => [
          %{
            "value" => "+1-555-0123",
            "type" => "work",
            "display" => "Work Phone",
            "primary" => true
          }
        ]
      }

      assert {:ok, _validated} = Validator.validate_scim_schema(scim_data)
    end
  end

  describe "addresses validation" do
    test "accepts all valid addresses canonical values" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "addresses" => [
          %{
            "formatted" => "123 Work St\nWork City, WS 12345 US",
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

      assert {:ok, _validated} = Validator.validate_scim_schema(scim_data)
    end

    test "rejects invalid addresses type" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "addresses" => [
          %{
            "formatted" => "123 Main St",
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

    test "validates addresses with all components" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "addresses" => [
          %{
            "formatted" => "Complete Address",
            "streetAddress" => "123 Main St",
            "locality" => "Anytown",
            "region" => "CA",
            "postalCode" => "12345",
            "country" => "US",
            "type" => "work",
            "primary" => false
          }
        ]
      }

      assert {:ok, _validated} = Validator.validate_scim_schema(scim_data)
    end
  end

  describe "photos validation" do
    test "accepts valid photos with reference type" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "photos" => [
          %{
            "value" => "https://example.com/photo.jpg",
            "type" => "photo",
            "display" => "Profile Photo",
            "primary" => true
          },
          %{
            "value" => "https://example.com/thumb.jpg",
            "type" => "thumbnail"
          }
        ]
      }

      assert {:ok, _validated} = Validator.validate_scim_schema(scim_data)
    end

    test "rejects invalid photos type" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "photos" => [
          %{
            "value" => "https://example.com/photo.jpg",
            # Invalid - should be photo or thumbnail
            "type" => "avatar"
          }
        ]
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :type)

      error_message = Keyword.get(errors, :type)
      assert String.contains?(error_message, "photo, thumbnail")
    end

    test "validates photos value as reference type" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "test.user",
        "photos" => [
          %{
            # Should be string (URI)
            "value" => 12345,
            "type" => "photo"
          }
        ]
      }

      assert {:error, errors} = Validator.validate_scim_schema(scim_data)
      assert Keyword.has_key?(errors, :"photos.value")

      error_message = Keyword.get(errors, :"photos.value")
      assert String.contains?(error_message, "string")
    end
  end

  describe "comprehensive validation with new attributes" do
    test "validates complex user with all new attributes" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "comprehensive.user",
        "name" => %{
          "givenName" => "Comprehensive",
          "familyName" => "User",
          "formatted" => "Comprehensive User"
        },
        "displayName" => "Comprehensive Test User",
        "emails" => [
          %{
            "value" => "comp@example.com",
            "type" => "work",
            "primary" => true
          }
        ],
        "phoneNumbers" => [
          %{
            "value" => "+1-555-0123",
            "type" => "work",
            "display" => "Work Phone"
          },
          %{
            "value" => "+1-555-0124",
            "type" => "mobile"
          }
        ],
        "addresses" => [
          %{
            "formatted" => "123 Work St, Work City, WS 12345",
            "streetAddress" => "123 Work St",
            "locality" => "Work City",
            "region" => "WS",
            "postalCode" => "12345",
            "country" => "US",
            "type" => "work",
            "primary" => true
          }
        ],
        "photos" => [
          %{
            "value" => "https://example.com/profile.jpg",
            "type" => "photo",
            "primary" => true
          }
        ],
        "active" => true
      }

      assert {:ok, validated} = Validator.validate_scim_schema(scim_data)
      assert validated == scim_data
    end

    test "validates minimal user still works" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "minimal.user"
      }

      assert {:ok, validated} = Validator.validate_scim_schema(scim_data)
      assert validated == scim_data
    end
  end
end
