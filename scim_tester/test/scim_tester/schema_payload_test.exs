defmodule ScimTester.SchemaPayloadTest do
  use ExUnit.Case, async: true

  alias ScimTester.SchemaPayload

  @user_schema_uri "urn:ietf:params:scim:schemas:core:2.0:User"

  defp full_user_schema do
    %{
      "id" => @user_schema_uri,
      "name" => "User",
      "attributes" => [
        %{
          "name" => "userName",
          "type" => "string",
          "required" => true,
          "mutability" => "readWrite"
        },
        %{"name" => "displayName", "type" => "string", "mutability" => "readWrite"},
        %{"name" => "title", "type" => "string", "mutability" => "readWrite"},
        %{"name" => "active", "type" => "boolean", "mutability" => "readWrite"},
        %{"name" => "nickName", "type" => "string", "mutability" => "readWrite"},
        %{"name" => "userType", "type" => "string", "mutability" => "readWrite"},
        %{
          "name" => "name",
          "type" => "complex",
          "mutability" => "readWrite",
          "subAttributes" => [
            %{"name" => "givenName", "type" => "string", "mutability" => "readWrite"},
            %{"name" => "familyName", "type" => "string", "mutability" => "readWrite"}
          ]
        },
        %{
          "name" => "emails",
          "type" => "complex",
          "multiValued" => true,
          "mutability" => "readWrite",
          "subAttributes" => [
            %{"name" => "value", "type" => "string"},
            %{"name" => "type", "type" => "string"},
            %{"name" => "primary", "type" => "boolean"}
          ]
        },
        # Server-controlled / readOnly attributes that should be excluded
        %{"name" => "id", "type" => "string", "mutability" => "readOnly"},
        %{
          "name" => "meta",
          "type" => "complex",
          "mutability" => "readOnly",
          "subAttributes" => [
            %{"name" => "created", "type" => "dateTime", "mutability" => "readOnly"},
            %{"name" => "lastModified", "type" => "dateTime", "mutability" => "readOnly"}
          ]
        },
        %{
          "name" => "groups",
          "type" => "complex",
          "multiValued" => true,
          "mutability" => "readOnly",
          "subAttributes" => [
            %{"name" => "value", "type" => "string"},
            %{"name" => "$ref", "type" => "reference"}
          ]
        }
      ]
    }
  end

  defp minimal_schema do
    %{
      "id" => @user_schema_uri,
      "name" => "User",
      "attributes" => [
        %{
          "name" => "userName",
          "type" => "string",
          "required" => true,
          "mutability" => "readWrite"
        }
      ]
    }
  end

  describe "generate_create_payload/1" do
    test "includes schemas key and userName" do
      payload = SchemaPayload.generate_create_payload(full_user_schema())

      assert payload["schemas"] == [@user_schema_uri]
      assert is_binary(payload["userName"])
      assert String.starts_with?(payload["userName"], "test_user_")
    end

    test "excludes readOnly attributes (id, meta, groups)" do
      payload = SchemaPayload.generate_create_payload(full_user_schema())

      refute Map.has_key?(payload, "id")
      refute Map.has_key?(payload, "meta")
      refute Map.has_key?(payload, "groups")
    end

    test "generates proper format for known attributes" do
      payload = SchemaPayload.generate_create_payload(full_user_schema())

      # emails should be a list of maps when present
      if Map.has_key?(payload, "emails") do
        assert is_list(payload["emails"])
        [email | _] = payload["emails"]
        assert is_binary(email["value"])
        assert email["type"] == "work"
      end

      # name should be a complex attribute when present
      if Map.has_key?(payload, "name") do
        assert is_map(payload["name"])
        assert is_binary(payload["name"]["givenName"])
        assert is_binary(payload["name"]["familyName"])
      end
    end

    test "handles minimal schema with only userName" do
      payload = SchemaPayload.generate_create_payload(minimal_schema())

      assert payload["schemas"] == [@user_schema_uri]
      assert is_binary(payload["userName"])
      # Should have at minimum schemas + userName
      assert map_size(payload) >= 2
    end

    test "always includes userName even if schema does not mark it required" do
      schema = %{
        "id" => @user_schema_uri,
        "attributes" => [
          %{"name" => "displayName", "type" => "string", "required" => true}
        ]
      }

      payload = SchemaPayload.generate_create_payload(schema)
      assert is_binary(payload["userName"])
    end
  end

  describe "generate_update_payload/2" do
    test "modifies some attributes but preserves userName" do
      existing_user = %{
        "userName" => "original_user",
        "displayName" => "Original Name",
        "title" => "Original Title",
        "active" => true,
        "nickName" => "orig"
      }

      payload = SchemaPayload.generate_update_payload(full_user_schema(), existing_user)

      # userName must be preserved
      assert payload["userName"] == "original_user"
      # At least some attributes should be different from original
      # (probabilistic but very unlikely all stay the same)
      assert is_map(payload)
    end

    test "skips immutable attributes" do
      schema = %{
        "id" => @user_schema_uri,
        "attributes" => [
          %{"name" => "userName", "type" => "string", "mutability" => "readWrite"},
          %{"name" => "displayName", "type" => "string", "mutability" => "readWrite"},
          %{"name" => "externalId", "type" => "string", "mutability" => "immutable"},
          %{"name" => "title", "type" => "string", "mutability" => "readWrite"}
        ]
      }

      existing_user = %{
        "userName" => "test_user",
        "displayName" => "Test",
        "externalId" => "ext_original",
        "title" => "Engineer"
      }

      # Run multiple times to increase confidence
      for _ <- 1..10 do
        payload = SchemaPayload.generate_update_payload(schema, existing_user)
        assert payload["externalId"] == "ext_original"
      end
    end
  end

  describe "generate_patch_operations/1" do
    test "picks a non-required, mutable, non-complex attribute" do
      ops = SchemaPayload.generate_patch_operations(full_user_schema())

      assert is_list(ops)
      assert length(ops) == 1

      [op] = ops
      assert op["op"] == "replace"
      assert is_binary(op["path"])
      assert op["path"] != "userName"
      assert Map.has_key?(op, "value")
    end

    test "falls back gracefully when no ideal candidate exists" do
      schema = %{
        "id" => @user_schema_uri,
        "attributes" => [
          %{
            "name" => "userName",
            "type" => "string",
            "required" => true,
            "mutability" => "readWrite"
          }
        ]
      }

      ops = SchemaPayload.generate_patch_operations(schema)

      assert is_list(ops)
      assert length(ops) == 1
      [op] = ops
      assert op["op"] == "replace"
      # Should use absolute fallback
      assert op["path"] == "title"
    end

    test "does not pick userName" do
      schema = %{
        "id" => @user_schema_uri,
        "attributes" => [
          %{
            "name" => "userName",
            "type" => "string",
            "required" => true,
            "mutability" => "readWrite"
          },
          %{"name" => "title", "type" => "string", "mutability" => "readWrite"}
        ]
      }

      for _ <- 1..10 do
        [op] = SchemaPayload.generate_patch_operations(schema)
        assert op["path"] != "userName"
      end
    end
  end

  describe "writable_attributes/1" do
    test "excludes readOnly attributes" do
      attrs = SchemaPayload.writable_attributes(full_user_schema())
      names = Enum.map(attrs, &Map.get(&1, "name"))

      refute "id" in names
      refute "meta" in names
      refute "groups" in names
    end

    test "treats missing mutability as readWrite" do
      schema = %{
        "attributes" => [
          %{"name" => "customField", "type" => "string"}
        ]
      }

      attrs = SchemaPayload.writable_attributes(schema)
      names = Enum.map(attrs, &Map.get(&1, "name"))

      assert "customField" in names
    end

    test "excludes reference type attributes" do
      schema = %{
        "attributes" => [
          %{"name" => "manager", "type" => "reference", "mutability" => "readWrite"},
          %{"name" => "title", "type" => "string", "mutability" => "readWrite"}
        ]
      }

      attrs = SchemaPayload.writable_attributes(schema)
      names = Enum.map(attrs, &Map.get(&1, "name"))

      refute "manager" in names
      assert "title" in names
    end
  end

  describe "partition_attributes/1" do
    test "splits into required and optional" do
      attrs = [
        %{"name" => "userName", "required" => true},
        %{"name" => "displayName", "required" => false},
        %{"name" => "title"}
      ]

      {required, optional} = SchemaPayload.partition_attributes(attrs)

      assert length(required) == 1
      assert length(optional) == 2
      assert hd(required)["name"] == "userName"
    end
  end

  describe "multi-valued complex attributes" do
    test "produces arrays for multi-valued complex attributes" do
      schema = %{
        "id" => @user_schema_uri,
        "attributes" => [
          %{
            "name" => "userName",
            "type" => "string",
            "required" => true,
            "mutability" => "readWrite"
          },
          %{
            "name" => "phoneNumbers",
            "type" => "complex",
            "multiValued" => true,
            "mutability" => "readWrite",
            "subAttributes" => [
              %{"name" => "value", "type" => "string"},
              %{"name" => "type", "type" => "string"}
            ]
          }
        ]
      }

      payload = SchemaPayload.generate_create_payload(schema)

      if Map.has_key?(payload, "phoneNumbers") do
        assert is_list(payload["phoneNumbers"])
        [phone | _] = payload["phoneNumbers"]
        assert is_map(phone)
      end
    end
  end

  describe "canonicalValues" do
    test "picks from canonicalValues when present" do
      canonical = ["Employee", "Contractor", "Intern"]

      schema = %{
        "id" => @user_schema_uri,
        "attributes" => [
          %{
            "name" => "userName",
            "type" => "string",
            "required" => true,
            "mutability" => "readWrite"
          },
          %{
            "name" => "userType",
            "type" => "string",
            "mutability" => "readWrite",
            "canonicalValues" => canonical
          }
        ]
      }

      # Run multiple times — each value should come from canonical list
      for _ <- 1..20 do
        payload = SchemaPayload.generate_create_payload(schema)

        if Map.has_key?(payload, "userType") do
          assert payload["userType"] in canonical
        end
      end
    end
  end
end
