defmodule ExScim.Users.PatcherTest do
  use ExUnit.Case, async: true

  import ExScim.TestFixtures
  import ExScim.SCIMComplianceHelpers

  alias ExScim.Users.Patcher

  describe "patch/2 with maps" do
    setup do
      user_map = %{
        "id" => "user-123",
        "userName" => "john.doe",
        "name" => %{
          "givenName" => "John",
          "familyName" => "Doe"
        },
        "displayName" => "John Doe",
        "emails" => [
          %{"value" => "john@work.com", "type" => "work", "primary" => true},
          %{"value" => "john@home.com", "type" => "home", "primary" => false}
        ],
        "phoneNumbers" => [
          %{"value" => "+1-555-0123", "type" => "work"},
          %{"value" => "+1-555-0124", "type" => "mobile"}
        ],
        "active" => true
      }

      {:ok, user_map: user_map}
    end

    test "handles replace operation on simple attribute", %{user_map: user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "displayName",
            "value" => "John D. Doe"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      assert patched_user["displayName"] == "John D. Doe"
      # Unchanged
      assert patched_user["userName"] == "john.doe"
    end

    test "handles replace operation on nested attribute", %{user_map: user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "name.givenName",
            "value" => "Jonathan"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      assert patched_user["name"]["givenName"] == "Jonathan"
      # Unchanged
      assert patched_user["name"]["familyName"] == "Doe"
    end

    test "handles add operation on existing array", %{user_map: user_map} do
      new_email = %{"value" => "john@personal.com", "type" => "personal"}

      patch_ops = %{
        "Operations" => [
          %{
            "op" => "add",
            "path" => "emails",
            "value" => new_email
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      emails = patched_user["emails"]

      assert length(emails) == 3
      assert Enum.any?(emails, fn email -> email["value"] == "john@personal.com" end)
      # Original preserved
      assert Enum.any?(emails, fn email -> email["value"] == "john@work.com" end)
    end

    test "handles add operation creating new array", %{user_map: user_map} do
      user_without_phones = Map.delete(user_map, "phoneNumbers")

      patch_ops = %{
        "Operations" => [
          %{
            "op" => "add",
            "path" => "phoneNumbers",
            "value" => %{"value" => "+1-555-9999", "type" => "mobile"}
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_without_phones, patch_ops)
      assert patched_user["phoneNumbers"] == [%{"value" => "+1-555-9999", "type" => "mobile"}]
    end

    test "handles remove operation on simple attribute", %{user_map: user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "remove",
            "path" => "displayName"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      assert is_nil(patched_user["displayName"])
      # Unchanged
      assert patched_user["userName"] == "john.doe"
    end

    test "handles remove operation on nested attribute", %{user_map: user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "remove",
            "path" => "name.givenName"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      assert is_nil(patched_user["name"]["givenName"])
      # Unchanged
      assert patched_user["name"]["familyName"] == "Doe"
    end

    test "handles add operation with no path (merge at root)", %{user_map: user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "add",
            "path" => nil,
            "value" => %{
              "title" => "Senior Engineer",
              "department" => "Engineering"
            }
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      assert patched_user["title"] == "Senior Engineer"
      assert patched_user["department"] == "Engineering"
      # Original preserved
      assert patched_user["userName"] == "john.doe"
    end

    test "handles replace operation with no path (merge at root)", %{user_map: user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => nil,
            "value" => %{
              "displayName" => "Replaced Name",
              "title" => "New Title"
            }
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      assert patched_user["displayName"] == "Replaced Name"
      assert patched_user["title"] == "New Title"
      # Original preserved
      assert patched_user["userName"] == "john.doe"
    end

    test "handles remove operation with no path (clears all)", %{user_map: _user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "remove",
            "path" => nil
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(%{"test" => "data"}, patch_ops)
      assert patched_user == %{}
    end

    test "handles multiple operations in sequence", %{user_map: user_map} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "displayName",
            "value" => "Updated Name"
          },
          %{
            "op" => "add",
            "path" => "title",
            "value" => "Engineer"
          },
          %{
            "op" => "remove",
            "path" => "active"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, patch_ops)
      assert patched_user["displayName"] == "Updated Name"
      assert patched_user["title"] == "Engineer"
      assert is_nil(patched_user["active"])
      # Unchanged
      assert patched_user["userName"] == "john.doe"
    end

    test "validates operation structure" do
      invalid_patches = [
        # Missing Operations key
        %{"ops" => []},
        # Operations not an array
        %{"Operations" => "not_array"},
        # Empty operations array
        %{"Operations" => []},
        # Invalid operation - missing op
        %{"Operations" => [%{"path" => "test", "value" => "value"}]},
        # Invalid operation - unknown op
        %{"Operations" => [%{"op" => "invalid", "path" => "test", "value" => "value"}]},
        # Add/replace without value
        %{"Operations" => [%{"op" => "add", "path" => "test"}]}
      ]

      for invalid_patch <- invalid_patches do
        result = Patcher.patch(%{}, invalid_patch)

        assert match?({:error, _}, result),
               "Expected error for invalid patch: #{inspect(invalid_patch)}"
      end
    end

    test "returns error for runtime exceptions" do
      # This should cause a runtime error during patching
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "very.deep.nested.path.that.does.not.exist",
            "value" => "test"
          }
        ]
      }

      # Should handle the error gracefully
      assert {:error, _reason} = Patcher.patch(%{}, patch_ops)
    end
  end

  describe "patch/2 with structs" do
    setup do
      # Create a domain user struct for testing
      domain_user = %ExScim.Users.User{
        id: "user-123",
        user_name: "john.doe",
        display_name: "John Doe",
        active: true,
        external_id: "ext-123",
        meta_created: ~U[2024-01-01 12:00:00Z],
        meta_last_modified: ~U[2024-01-01 12:00:00Z]
      }

      {:ok, domain_user: domain_user}
    end

    test "handles replace operation on struct field", %{domain_user: domain_user} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "display_name",
            "value" => "Updated Display Name"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(domain_user, patch_ops)
      assert patched_user.display_name == "Updated Display Name"
      # Unchanged
      assert patched_user.user_name == "john.doe"
      # Struct preserved
      assert patched_user.__struct__ == ExScim.Users.User
    end

    test "handles string keys mapped to atom fields", %{domain_user: domain_user} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "display_name",
            "value" => "Jonathan Doe"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(domain_user, patch_ops)
      assert patched_user.display_name == "Jonathan Doe"
      # Unchanged
      assert patched_user.user_name == "john.doe"
    end

    test "handles add operation on struct", %{domain_user: domain_user} do
      # Note: For structs, "add" behaves like replace since structs have fixed fields
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "add",
            "path" => "title",
            "value" => "Engineer"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(domain_user, patch_ops)
      assert patched_user.title == "Engineer"
    end

    test "handles remove operation on struct field", %{domain_user: domain_user} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "remove",
            "path" => "display_name"
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(domain_user, patch_ops)
      assert is_nil(patched_user.display_name)
      # Unchanged
      assert patched_user.user_name == "john.doe"
    end

    test "gracefully handles non-existent struct fields", %{domain_user: domain_user} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "non_existent_field",
            "value" => "test"
          }
        ]
      }

      # Should not crash, but field won't be added to struct
      assert {:ok, patched_user} = Patcher.patch(domain_user, patch_ops)
      # Original preserved
      assert patched_user.user_name == "john.doe"
      refute Map.has_key?(patched_user, :non_existent_field)
    end

    test "handles multiple operations on struct", %{domain_user: domain_user} do
      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "title",
            "value" => "Senior Engineer"
          },
          %{
            "op" => "replace",
            "path" => "display_name",
            "value" => "Jonathan Doe"
          },
          %{
            "op" => "replace",
            "path" => "active",
            "value" => false
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(domain_user, patch_ops)
      assert patched_user.title == "Senior Engineer"
      assert patched_user.display_name == "Jonathan Doe"
      assert patched_user.active == false
      # Unchanged
      assert patched_user.user_name == "john.doe"
    end
  end

  describe "SCIM compliance" do
    test "validates patch operations format" do
      valid_patch = valid_patch_operations()
      assert_scim_patch_operations(valid_patch)

      user_map = %{"userName" => "test", "active" => true}
      assert {:ok, _result} = Patcher.patch(user_map, valid_patch)
    end

    test "handles SCIM-compliant patch operations" do
      user_map = %{
        "userName" => "john.doe",
        "name" => %{"givenName" => "John", "familyName" => "Doe"},
        "emails" => [
          %{"value" => "john@work.com", "type" => "work", "primary" => true}
        ],
        "active" => true
      }

      # SCIM-compliant patch operations
      scim_patch = %{
        "Operations" => [
          # Replace simple attribute
          %{
            "op" => "replace",
            "path" => "name.givenName",
            "value" => "Jonathan"
          },
          # Add to multi-valued attribute
          %{
            "op" => "add",
            "path" => "emails",
            "value" => %{
              "value" => "jonathan@home.com",
              "type" => "home",
              "primary" => false
            }
          },
          # Simple replace on active status
          %{
            "op" => "replace",
            "path" => "active",
            "value" => false
          }
        ]
      }

      assert {:ok, patched_user} = Patcher.patch(user_map, scim_patch)
      assert patched_user["name"]["givenName"] == "Jonathan"
      assert length(patched_user["emails"]) >= 1
    end

    test "handles edge cases in patch operations" do
      user_map = %{"userName" => "test", "active" => true}

      edge_cases = [
        # Empty string path
        %{"Operations" => [%{"op" => "replace", "path" => "", "value" => "test"}]},
        # Null value
        %{"Operations" => [%{"op" => "replace", "path" => "active", "value" => nil}]},
        # Complex value
        %{
          "Operations" => [
            %{"op" => "add", "path" => "complex", "value" => %{"nested" => %{"deep" => "value"}}}
          ]
        }
      ]

      for edge_case <- edge_cases do
        # Should handle gracefully without crashing
        result = Patcher.patch(user_map, edge_case)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "error handling" do
    test "returns appropriate error messages for invalid operations" do
      user_map = %{"userName" => "test"}

      test_cases = [
        {
          %{"Operations" => [%{"op" => "invalid_op", "path" => "test", "value" => "value"}]},
          "Unsupported op"
        }
      ]

      for {invalid_patch, expected_error_content} <- test_cases do
        assert {:error, error_message} = Patcher.patch(user_map, invalid_patch)
        assert String.contains?(error_message, expected_error_content)
      end
    end

    test "preserves original data when patch fails" do
      original_user = %{"userName" => "test", "active" => true}

      invalid_patch = %{
        "Operations" => [
          %{"op" => "unsupported_operation", "path" => "test", "value" => "value"}
        ]
      }

      # Patch should fail
      assert {:error, _} = Patcher.patch(original_user, invalid_patch)

      # Original user should be unchanged (since we're not mutating it)
      assert original_user == %{"userName" => "test", "active" => true}
    end
  end

  describe "performance and compatibility" do
    test "works with both small and large user objects" do
      # Small user
      small_user = %{"userName" => "test"}

      # Large complex user
      large_user = complex_scim_user_attrs()

      patch_ops = %{
        "Operations" => [
          %{"op" => "replace", "path" => "userName", "value" => "updated"}
        ]
      }

      assert {:ok, small_result} = Patcher.patch(small_user, patch_ops)
      assert small_result["userName"] == "updated"

      assert {:ok, large_result} = Patcher.patch(large_user, patch_ops)
      assert large_result["userName"] == "updated"
      # Other complex fields should be preserved
      assert large_result["emails"] == large_user["emails"]
    end

    test "handles nested operations efficiently" do
      user_with_deep_nesting = %{
        "level1" => %{
          "level2" => %{
            "level3" => %{
              "target" => "original_value"
            }
          }
        }
      }

      patch_ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => "level1.level2.level3.target",
            "value" => "new_value"
          }
        ]
      }

      assert {:ok, result} = Patcher.patch(user_with_deep_nesting, patch_ops)
      assert get_in(result, ["level1", "level2", "level3", "target"]) == "new_value"
    end
  end
end
