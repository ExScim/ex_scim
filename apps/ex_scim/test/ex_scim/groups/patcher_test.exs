defmodule ExScim.Groups.PatcherTest do
  use ExUnit.Case, async: true

  alias ExScim.Groups.Patcher

  describe "patch/2 with maps" do
    setup do
      group = %{
        "id" => "group-123",
        "displayName" => "Engineering",
        "members" => [
          %{"value" => "user-1", "display" => "Alice"},
          %{"value" => "user-2", "display" => "Bob"}
        ]
      }

      {:ok, group: group}
    end

    test "replace displayName", %{group: group} do
      ops = %{"Operations" => [%{"op" => "replace", "path" => "displayName", "value" => "Eng"}]}

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched["displayName"] == "Eng"
      assert patched["members"] == group["members"]
    end

    test "add member to existing members list", %{group: group} do
      new_member = %{"value" => "user-3", "display" => "Charlie"}

      ops = %{"Operations" => [%{"op" => "add", "path" => "members", "value" => new_member}]}

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert length(patched["members"]) == 3
      assert Enum.any?(patched["members"], &(&1["value"] == "user-3"))
    end

    test "replace members entirely", %{group: group} do
      new_members = [%{"value" => "user-99", "display" => "Zoe"}]

      ops = %{"Operations" => [%{"op" => "replace", "path" => "members", "value" => new_members}]}

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched["members"] == new_members
    end

    test "remove a field", %{group: group} do
      ops = %{"Operations" => [%{"op" => "remove", "path" => "members"}]}

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert is_nil(patched["members"])
    end

    test "multiple operations applied in order", %{group: group} do
      ops = %{
        "Operations" => [
          %{"op" => "replace", "path" => "displayName", "value" => "Platform"},
          %{
            "op" => "add",
            "path" => "members",
            "value" => %{"value" => "user-3", "display" => "Charlie"}
          }
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched["displayName"] == "Platform"
      assert length(patched["members"]) == 3
    end

    test "add without path merges at root", %{group: group} do
      ops = %{
        "Operations" => [
          %{"op" => "add", "value" => %{"description" => "The engineering team"}}
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched["description"] == "The engineering team"
      assert patched["displayName"] == "Engineering"
    end

    test "add members to group that has no members key" do
      group = %{"id" => "group-empty", "displayName" => "New Group"}
      new_member = %{"value" => "user-1", "display" => "Alice"}

      ops = %{"Operations" => [%{"op" => "add", "path" => "members", "value" => new_member}]}

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched["members"] == [new_member]
    end
  end

  describe "patch/2 with structs" do
    setup do
      group = %ExScim.Groups.Group{
        id: "group-123",
        display_name: "Engineering",
        members: [
          %{"value" => "user-1", "display" => "Alice"}
        ],
        active: true
      }

      {:ok, group: group}
    end

    test "replace on struct field", %{group: group} do
      ops = %{
        "Operations" => [%{"op" => "replace", "path" => "display_name", "value" => "Platform"}]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched.display_name == "Platform"
      assert patched.__struct__ == ExScim.Groups.Group
    end

    test "remove on struct field sets it to nil", %{group: group} do
      ops = %{"Operations" => [%{"op" => "remove", "path" => "active"}]}

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert is_nil(patched.active)
      assert patched.display_name == "Engineering"
    end

    test "ignores non-existent struct fields", %{group: group} do
      ops = %{
        "Operations" => [
          %{"op" => "replace", "path" => "nonexistent", "value" => "ignored"}
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched.display_name == "Engineering"
      refute Map.has_key?(patched, :nonexistent)
    end
  end

  describe "patch/2 validation" do
    test "rejects missing Operations key" do
      assert {:error, "Missing required Operations field"} =
               Patcher.patch(%{}, %{"ops" => []})
    end

    test "rejects non-list Operations" do
      assert {:error, "Operations must be an array"} =
               Patcher.patch(%{}, %{"Operations" => "not_list"})
    end

    test "rejects empty Operations list" do
      assert {:error, "Operations array cannot be empty"} =
               Patcher.patch(%{}, %{"Operations" => []})
    end

    test "rejects non-map input" do
      assert {:error, "Patch operations must be a map"} =
               Patcher.patch(%{}, "not a map")
    end

    test "returns error for unknown op" do
      ops = %{"Operations" => [%{"op" => "invalid", "path" => "x", "value" => "y"}]}

      assert {:error, msg} = Patcher.patch(%{}, ops)
      assert msg =~ "Unsupported op"
    end

    test "returns error for missing op field" do
      ops = %{"Operations" => [%{"path" => "x", "value" => "y"}]}

      assert {:error, msg} = Patcher.patch(%{}, ops)
      assert msg =~ "missing or invalid 'op' field"
    end

    test "returns error for add without value" do
      ops = %{"Operations" => [%{"op" => "add", "path" => "x"}]}

      assert {:error, msg} = Patcher.patch(%{}, ops)
      assert msg =~ "Add operation missing required 'value' field"
    end
  end
end
