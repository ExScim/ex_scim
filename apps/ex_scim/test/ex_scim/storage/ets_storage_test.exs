defmodule ExScim.Storage.EtsStorageTest do
  use ExUnit.Case, async: false

  alias ExScim.Storage.EtsStorage

  setup do
    EtsStorage.clear_all()
    :ok
  end

  describe "create_user/2" do
    test "creates user and returns it with a generated ID" do
      attrs = %{"userName" => "alice"}

      assert {:ok, user} = EtsStorage.create_user(attrs)
      assert is_binary(user["id"])
      assert user["userName"] == "alice"
    end

    test "preserves a caller-supplied ID" do
      attrs = %{"id" => "custom-id", "userName" => "bob"}

      assert {:ok, user} = EtsStorage.create_user(attrs)
      assert user["id"] == "custom-id"
    end

    test "rejects duplicate userName" do
      attrs = %{"userName" => "alice"}
      assert {:ok, _} = EtsStorage.create_user(attrs)

      assert {:error, :username_taken} = EtsStorage.create_user(%{"userName" => "alice"})
    end

    test "rejects duplicate externalId" do
      attrs = %{"userName" => "alice", "externalId" => "ext-1"}
      assert {:ok, _} = EtsStorage.create_user(attrs)

      assert {:error, :external_id_taken} =
               EtsStorage.create_user(%{"userName" => "bob", "externalId" => "ext-1"})
    end

    test "rejects duplicate user ID" do
      attrs = %{"id" => "same-id", "userName" => "alice"}
      assert {:ok, _} = EtsStorage.create_user(attrs)

      assert {:error, :user_id_taken} =
               EtsStorage.create_user(%{"id" => "same-id", "userName" => "bob"})
    end

    test "allows nil externalId for multiple users" do
      assert {:ok, _} = EtsStorage.create_user(%{"userName" => "alice"})
      assert {:ok, _} = EtsStorage.create_user(%{"userName" => "bob"})
    end
  end

  describe "get_user/2" do
    test "returns existing user" do
      {:ok, created} = EtsStorage.create_user(%{"userName" => "alice"})

      assert {:ok, fetched} = EtsStorage.get_user(created["id"])
      assert fetched["userName"] == "alice"
      assert fetched["id"] == created["id"]
    end

    test "returns {:error, :not_found} for missing ID" do
      assert {:error, :not_found} = EtsStorage.get_user("nonexistent")
    end
  end

  describe "list_users/4" do
    test "returns all users with total count" do
      for i <- 1..3 do
        EtsStorage.create_user(%{"userName" => "user#{i}"})
      end

      assert {:ok, users, 3} = EtsStorage.list_users()
      assert length(users) == 3
    end

    test "returns empty list when no users exist" do
      assert {:ok, [], 0} = EtsStorage.list_users()
    end

    test "respects start_index and count pagination" do
      for i <- 1..5 do
        EtsStorage.create_user(%{"userName" => "user#{i}", "displayName" => "User #{i}"})
      end

      assert {:ok, page, 5} =
               EtsStorage.list_users(nil, [sort_by: {"userName", :asc}], start_index: 2, count: 2)

      assert length(page) == 2
    end

    test "applies filter when provided" do
      EtsStorage.create_user(%{"userName" => "alice", "active" => true})
      EtsStorage.create_user(%{"userName" => "bob", "active" => false})

      filter_ast = {:eq, "active", true}
      assert {:ok, users, 1} = EtsStorage.list_users(filter_ast)
      assert length(users) == 1
      assert hd(users)["userName"] == "alice"
    end

    test "applies sorting" do
      EtsStorage.create_user(%{"userName" => "charlie"})
      EtsStorage.create_user(%{"userName" => "alice"})
      EtsStorage.create_user(%{"userName" => "bob"})

      assert {:ok, users, 3} = EtsStorage.list_users(nil, sort_by: {"userName", :asc})
      names = Enum.map(users, & &1["userName"])
      assert names == ["alice", "bob", "charlie"]

      assert {:ok, users_desc, 3} = EtsStorage.list_users(nil, sort_by: {"userName", :desc})
      names_desc = Enum.map(users_desc, & &1["userName"])
      assert names_desc == ["charlie", "bob", "alice"]
    end
  end

  describe "update_user/3" do
    test "updates existing user" do
      {:ok, created} = EtsStorage.create_user(%{"userName" => "alice", "active" => true})

      assert {:ok, updated} =
               EtsStorage.update_user(created["id"], %{"userName" => "alice", "active" => false})

      assert updated["active"] == false
      assert updated["id"] == created["id"]
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} =
               EtsStorage.update_user("nonexistent", %{"userName" => "alice"})
    end

    test "rejects update when new userName is taken by another user" do
      {:ok, _} = EtsStorage.create_user(%{"userName" => "alice"})
      {:ok, bob} = EtsStorage.create_user(%{"userName" => "bob"})

      assert {:error, :username_taken} =
               EtsStorage.update_user(bob["id"], %{"userName" => "alice"})
    end

    test "allows updating user while keeping same userName" do
      {:ok, created} = EtsStorage.create_user(%{"userName" => "alice", "active" => true})

      assert {:ok, updated} =
               EtsStorage.update_user(created["id"], %{"userName" => "alice", "active" => false})

      assert updated["active"] == false
    end
  end

  describe "replace_user/3" do
    test "replaces existing user entirely" do
      {:ok, created} =
        EtsStorage.create_user(%{
          "userName" => "alice",
          "displayName" => "Alice",
          "active" => true
        })

      replacement = %{"userName" => "alice", "title" => "Engineer"}

      assert {:ok, replaced} = EtsStorage.replace_user(created["id"], replacement)
      assert replaced["userName"] == "alice"
      assert replaced["title"] == "Engineer"
      assert replaced["id"] == created["id"]
      # Old fields are gone - this is a full replace
      refute Map.has_key?(replaced, "displayName")
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} =
               EtsStorage.replace_user("nonexistent", %{"userName" => "alice"})
    end
  end

  describe "delete_user/2" do
    test "deletes existing user" do
      {:ok, created} = EtsStorage.create_user(%{"userName" => "alice"})

      assert :ok = EtsStorage.delete_user(created["id"])
      assert {:error, :not_found} = EtsStorage.get_user(created["id"])
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = EtsStorage.delete_user("nonexistent")
    end

    test "frees the userName for reuse after deletion" do
      {:ok, created} = EtsStorage.create_user(%{"userName" => "alice"})
      :ok = EtsStorage.delete_user(created["id"])

      assert {:ok, _} = EtsStorage.create_user(%{"userName" => "alice"})
    end

    test "frees the externalId for reuse after deletion" do
      {:ok, created} =
        EtsStorage.create_user(%{"userName" => "alice", "externalId" => "ext-1"})

      :ok = EtsStorage.delete_user(created["id"])

      assert {:ok, _} =
               EtsStorage.create_user(%{"userName" => "bob", "externalId" => "ext-1"})
    end
  end

  describe "user_exists?/2" do
    test "returns true for existing user" do
      {:ok, created} = EtsStorage.create_user(%{"userName" => "alice"})
      assert EtsStorage.user_exists?(created["id"])
    end

    test "returns false for missing user" do
      refute EtsStorage.user_exists?("nonexistent")
    end
  end

  describe "create_group/2" do
    test "creates group and returns it with a generated ID" do
      attrs = %{"displayName" => "Engineering"}

      assert {:ok, group} = EtsStorage.create_group(attrs)
      assert is_binary(group["id"])
      assert group["displayName"] == "Engineering"
    end

    test "preserves a caller-supplied ID" do
      attrs = %{"id" => "grp-1", "displayName" => "Engineering"}

      assert {:ok, group} = EtsStorage.create_group(attrs)
      assert group["id"] == "grp-1"
    end

    test "rejects duplicate displayName" do
      assert {:ok, _} = EtsStorage.create_group(%{"displayName" => "Engineering"})

      assert {:error, :display_name_taken} =
               EtsStorage.create_group(%{"displayName" => "Engineering"})
    end

    test "rejects duplicate externalId" do
      assert {:ok, _} =
               EtsStorage.create_group(%{"displayName" => "Eng", "externalId" => "ext-g1"})

      assert {:error, :external_id_taken} =
               EtsStorage.create_group(%{"displayName" => "Ops", "externalId" => "ext-g1"})
    end
  end

  describe "get_group/2" do
    test "returns existing group" do
      {:ok, created} = EtsStorage.create_group(%{"displayName" => "Engineering"})

      assert {:ok, fetched} = EtsStorage.get_group(created["id"])
      assert fetched["displayName"] == "Engineering"
    end

    test "returns {:error, :not_found} for missing group" do
      assert {:error, :not_found} = EtsStorage.get_group("nonexistent")
    end
  end

  describe "list_groups/4" do
    test "returns all groups with total count" do
      for i <- 1..3 do
        EtsStorage.create_group(%{"displayName" => "Group #{i}"})
      end

      assert {:ok, groups, 3} = EtsStorage.list_groups()
      assert length(groups) == 3
    end

    test "returns empty list when no groups exist" do
      assert {:ok, [], 0} = EtsStorage.list_groups()
    end

    test "applies sorting" do
      EtsStorage.create_group(%{"displayName" => "Zebra"})
      EtsStorage.create_group(%{"displayName" => "Alpha"})
      EtsStorage.create_group(%{"displayName" => "Middle"})

      assert {:ok, groups, 3} =
               EtsStorage.list_groups(nil, sort_by: {"displayName", :asc})

      names = Enum.map(groups, & &1["displayName"])
      assert names == ["Alpha", "Middle", "Zebra"]
    end
  end

  describe "update_group/3" do
    test "updates existing group" do
      {:ok, created} = EtsStorage.create_group(%{"displayName" => "Eng"})

      assert {:ok, updated} =
               EtsStorage.update_group(created["id"], %{
                 "displayName" => "Engineering",
                 "members" => [%{"value" => "user-1"}]
               })

      assert updated["displayName"] == "Engineering"
      assert updated["members"] == [%{"value" => "user-1"}]
    end

    test "returns error for non-existent group" do
      assert {:error, :not_found} =
               EtsStorage.update_group("nonexistent", %{"displayName" => "Eng"})
    end

    test "rejects update when new displayName is taken by another group" do
      {:ok, _} = EtsStorage.create_group(%{"displayName" => "Engineering"})
      {:ok, ops} = EtsStorage.create_group(%{"displayName" => "Operations"})

      assert {:error, :display_name_taken} =
               EtsStorage.update_group(ops["id"], %{"displayName" => "Engineering"})
    end
  end

  describe "replace_group/3" do
    test "replaces existing group entirely" do
      {:ok, created} =
        EtsStorage.create_group(%{
          "displayName" => "Eng",
          "members" => [%{"value" => "user-1"}]
        })

      replacement = %{"displayName" => "Engineering"}

      assert {:ok, replaced} = EtsStorage.replace_group(created["id"], replacement)
      assert replaced["displayName"] == "Engineering"
      assert replaced["id"] == created["id"]
      refute Map.has_key?(replaced, "members")
    end

    test "returns error for non-existent group" do
      assert {:error, :not_found} =
               EtsStorage.replace_group("nonexistent", %{"displayName" => "Eng"})
    end
  end

  describe "delete_group/2" do
    test "deletes existing group" do
      {:ok, created} = EtsStorage.create_group(%{"displayName" => "Engineering"})

      assert :ok = EtsStorage.delete_group(created["id"])
      assert {:error, :not_found} = EtsStorage.get_group(created["id"])
    end

    test "returns error for non-existent group" do
      assert {:error, :not_found} = EtsStorage.delete_group("nonexistent")
    end

    test "frees the displayName for reuse after deletion" do
      {:ok, created} = EtsStorage.create_group(%{"displayName" => "Engineering"})
      :ok = EtsStorage.delete_group(created["id"])

      assert {:ok, _} = EtsStorage.create_group(%{"displayName" => "Engineering"})
    end
  end

  describe "group_exists?/2" do
    test "returns true for existing group" do
      {:ok, created} = EtsStorage.create_group(%{"displayName" => "Engineering"})
      assert EtsStorage.group_exists?(created["id"])
    end

    test "returns false for missing group" do
      refute EtsStorage.group_exists?("nonexistent")
    end
  end

  describe "clear_all/0" do
    test "empties both user and group tables" do
      {:ok, _} = EtsStorage.create_user(%{"userName" => "alice"})
      {:ok, _} = EtsStorage.create_group(%{"displayName" => "Engineering"})

      assert :ok = EtsStorage.clear_all()

      assert {:ok, [], 0} = EtsStorage.list_users()
      assert {:ok, [], 0} = EtsStorage.list_groups()
    end

    test "frees uniqueness constraints after clear" do
      {:ok, _} = EtsStorage.create_user(%{"userName" => "alice", "externalId" => "ext-1"})
      {:ok, _} = EtsStorage.create_group(%{"displayName" => "Eng", "externalId" => "ext-g1"})

      EtsStorage.clear_all()

      assert {:ok, _} = EtsStorage.create_user(%{"userName" => "alice", "externalId" => "ext-1"})

      assert {:ok, _} =
               EtsStorage.create_group(%{"displayName" => "Eng", "externalId" => "ext-g1"})
    end
  end
end
