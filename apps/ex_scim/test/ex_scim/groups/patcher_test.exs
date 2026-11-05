defmodule ExScim.Groups.PatcherTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

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

  describe "patch/2 with filtered member paths" do
    setup do
      members = [
        %{"value" => "user-1", "display" => "Alice"},
        %{"value" => "user-2", "display" => "Bob"},
        %{"value" => "user-3", "display" => "Carol"}
      ]

      map = %{"id" => "group-123", "displayName" => "Eng", "members" => members}

      {:ok, map: map}
    end

    defp member_ids(members), do: Enum.map(members, & &1["value"])

    test "remove a single member from a group", %{map: group} do
      ops = %{
        "Operations" => [%{"op" => "remove", "path" => ~s(members[value eq "user-2"])}]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert member_ids(patched["members"]) == ["user-1", "user-3"]
    end

    test "remove a single member from a map", %{map: group} do
      ops = %{
        "Operations" => [%{"op" => "remove", "path" => ~s(members[value eq "user-2"])}]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert member_ids(patched["members"]) == ["user-1", "user-3"]
    end

    test "remove with a logical filter", %{map: group} do
      ops = %{
        "Operations" => [
          %{"op" => "remove", "path" => ~s(members[value eq "user-1" or display sw "Car"])}
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert member_ids(patched["members"]) == ["user-2"]
    end

    test "remove with a filter that matches nothing leaves members unchanged", %{map: group} do
      ops = %{
        "Operations" => [%{"op" => "remove", "path" => ~s(members[value eq "user-9"])}]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert patched["members"] == group["members"]
    end

    test "remove a sub-attribute of matching members", %{map: group} do
      ops = %{
        "Operations" => [%{"op" => "remove", "path" => ~s(members[value eq "user-1"].display)}]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert hd(patched["members"]) == %{"value" => "user-1"}
      assert length(patched["members"]) == 3
    end

    test "remove members listed in value", %{map: group} do
      ops = %{
        "Operations" => [
          %{
            "op" => "Remove",
            "path" => "members",
            "value" => [%{"value" => "user-1"}, %{"value" => "user-3"}]
          }
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert member_ids(patched["members"]) == ["user-2"]
    end

    test "replace a sub-attribute of matching members", %{map: group} do
      ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => ~s(members[value eq "user-2"].display),
            "value" => "Robert"
          }
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert Enum.at(patched["members"], 1) == %{"value" => "user-2", "display" => "Robert"}
    end

    test "replace matching members", %{map: group} do
      ops = %{
        "Operations" => [
          %{
            "op" => "replace",
            "path" => ~s(members[value eq "user-2"]),
            "value" => %{"value" => "user-4"}
          }
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert member_ids(patched["members"]) == ["user-1", "user-4", "user-3"]
    end

    test "add with an unmatched eq filter appends a new member", %{map: group} do
      ops = %{
        "Operations" => [
          %{
            "op" => "add",
            "path" => ~s(members[value eq "user-4"]),
            "value" => %{"display" => "Dave"}
          }
        ]
      }

      assert {:ok, patched} = Patcher.patch(group, ops)
      assert List.last(patched["members"]) == %{"value" => "user-4", "display" => "Dave"}
    end

    test "replace with a filter that matches nothing returns noTarget", %{map: group} do
      ops = %{
        "Operations" => [
          %{"op" => "replace", "path" => ~s(members[value eq "user-9"].display), "value" => "X"}
        ]
      }

      assert {:error, {:invalid_patch, :no_target, _}} = Patcher.patch(group, ops)
    end

    test "invalid filter returns invalidFilter", %{map: group} do
      ops = %{"Operations" => [%{"op" => "remove", "path" => "members[value zz 1]"}]}

      assert {:error, {:invalid_patch, :invalid_filter, _}} = Patcher.patch(group, ops)
    end
  end

  describe "patch/2 validation" do
    test "rejects missing Operations key" do
      assert {:error, {:invalid_patch, :invalid_syntax, "Missing required Operations field"}} =
               Patcher.patch(%{}, %{"ops" => []})
    end

    test "rejects non-list Operations" do
      assert {:error, {:invalid_patch, :invalid_syntax, "Operations must be an array"}} =
               Patcher.patch(%{}, %{"Operations" => "not_list"})
    end

    test "rejects empty Operations list" do
      assert {:error, {:invalid_patch, :invalid_syntax, "Operations array cannot be empty"}} =
               Patcher.patch(%{}, %{"Operations" => []})
    end

    test "rejects non-map input" do
      assert {:error, {:invalid_patch, :invalid_syntax, "Patch operations must be a map"}} =
               Patcher.patch(%{}, "not a map")
    end

    test "returns error for unknown op" do
      ops = %{"Operations" => [%{"op" => "invalid", "path" => "x", "value" => "y"}]}

      assert {:error, {:invalid_patch, :invalid_syntax, msg}} = Patcher.patch(%{}, ops)
      assert msg =~ "Unsupported op"
    end

    test "returns error for missing op field" do
      ops = %{"Operations" => [%{"path" => "x", "value" => "y"}]}

      assert {:error, {:invalid_patch, :invalid_syntax, msg}} = Patcher.patch(%{}, ops)
      assert msg =~ "missing or invalid 'op' field"
    end

    test "returns error for add without value" do
      ops = %{"Operations" => [%{"op" => "add", "path" => "x"}]}

      assert {:error, {:invalid_patch, :invalid_value, msg}} = Patcher.patch(%{}, ops)
      assert msg =~ "Add operation missing required 'value' field"
    end

    test "returns noTarget for remove without a path" do
      ops = %{"Operations" => [%{"op" => "remove"}]}

      assert {:error, {:invalid_patch, :no_target, _}} =
               Patcher.patch(%{"displayName" => "Eng"}, ops)
    end

    test "returns noTarget for a path through a non-map value" do
      ops = %{"Operations" => [%{"op" => "replace", "path" => "displayName.x", "value" => "y"}]}

      assert {:error, {:invalid_patch, :no_target, _}} =
               Patcher.patch(%{"displayName" => "Engineering"}, ops)
    end
  end
end
