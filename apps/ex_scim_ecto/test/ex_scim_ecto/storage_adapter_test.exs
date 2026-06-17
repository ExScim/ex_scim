defmodule ExScimEcto.StorageAdapterTest do
  use ExUnit.Case, async: false

  # Requires a live Postgres; excluded by default. Run with: mix test --include db
  @moduletag :db

  alias ExScimEcto.StorageAdapter
  alias ExScimEcto.TestRepo
  alias ExScimEcto.TestSupport.{User, UserEmail}
  alias ExScim.Scope

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)
  end

  # Restores user_model/group_model after a test overrides them.
  defp with_config(key, value, fun) do
    prev = Application.get_env(:ex_scim, key)
    Application.put_env(:ex_scim, key, value)

    try do
      fun.()
    after
      Application.put_env(:ex_scim, key, prev)
    end
  end

  defp user_attrs(id, name, extra \\ %{}) do
    Map.merge(%{id: id, user_name: name, display_name: name, active: true}, extra)
  end

  describe "user CRUD" do
    test "create then get round-trips the record" do
      assert {:ok, created} = StorageAdapter.create_user(user_attrs("u1", "alice"))
      assert created.id == "u1"

      assert {:ok, fetched} = StorageAdapter.get_user("u1")
      assert fetched.user_name == "alice"
      assert fetched.display_name == "alice"
      assert fetched.active == true
    end

    test "get returns :not_found for a missing user" do
      assert {:error, :not_found} = StorageAdapter.get_user("nope")
    end

    test "update merges the given fields" do
      {:ok, _} = StorageAdapter.create_user(user_attrs("u1", "alice"))

      assert {:ok, updated} = StorageAdapter.update_user("u1", %{display_name: "Alice A."})
      assert updated.display_name == "Alice A."
      # untouched field retained
      assert updated.user_name == "alice"
    end

    test "update returns :not_found for a missing user" do
      assert {:error, :not_found} = StorageAdapter.update_user("nope", %{display_name: "X"})
    end

    test "replace overwrites the record" do
      {:ok, _} = StorageAdapter.create_user(user_attrs("u1", "alice", %{external_id: "ext"}))

      replacement = %User{id: "u1", user_name: "alice2", display_name: "Alice Two"}
      assert {:ok, replaced} = StorageAdapter.replace_user("u1", replacement)
      assert replaced.user_name == "alice2"
      assert replaced.display_name == "Alice Two"
    end

    test "delete removes the user" do
      {:ok, _} = StorageAdapter.create_user(user_attrs("u1", "alice"))

      assert :ok = StorageAdapter.delete_user("u1")
      assert {:error, :not_found} = StorageAdapter.get_user("u1")
    end

    test "delete returns :not_found for a missing user" do
      assert {:error, :not_found} = StorageAdapter.delete_user("nope")
    end

    test "user_exists?/1 reflects presence" do
      refute StorageAdapter.user_exists?("u1")
      {:ok, _} = StorageAdapter.create_user(user_attrs("u1", "alice"))
      assert StorageAdapter.user_exists?("u1")
    end

    test "duplicate user_name returns changeset validation errors" do
      {:ok, _} = StorageAdapter.create_user(user_attrs("u1", "alice"))

      assert {:error, errors} = StorageAdapter.create_user(user_attrs("u2", "alice"))
      assert is_list(errors)
      assert Enum.any?(errors, &(&1["path"] == "user_name"))
    end
  end

  describe "group CRUD" do
    test "create, get, update, delete" do
      assert {:ok, _} = StorageAdapter.create_group(%{id: "g1", display_name: "Eng"})

      assert {:ok, fetched} = StorageAdapter.get_group("g1")
      assert fetched.display_name == "Eng"

      assert {:ok, updated} = StorageAdapter.update_group("g1", %{display_name: "Engineering"})
      assert updated.display_name == "Engineering"

      assert StorageAdapter.group_exists?("g1")
      assert :ok = StorageAdapter.delete_group("g1")
      assert {:error, :not_found} = StorageAdapter.get_group("g1")
      refute StorageAdapter.group_exists?("g1")
    end

    test "get returns :not_found for a missing group" do
      assert {:error, :not_found} = StorageAdapter.get_group("nope")
    end
  end

  describe "list_users" do
    setup do
      {:ok, _} = StorageAdapter.create_user(user_attrs("u1", "alice"))
      {:ok, _} = StorageAdapter.create_user(user_attrs("u2", "bob"))
      {:ok, _} = StorageAdapter.create_user(user_attrs("u3", "carol"))
      :ok
    end

    test "returns all users with a total count" do
      assert {:ok, users, 3} = StorageAdapter.list_users(nil, [], [])
      assert length(users) == 3
    end

    test "applies a filter (camelCase auto-mapped to snake_case column)" do
      assert {:ok, [user], 1} = StorageAdapter.list_users({:eq, "userName", "alice"}, [], [])
      assert user.user_name == "alice"
    end

    test "applies sorting (descending by user_name)" do
      {:ok, users, _} = StorageAdapter.list_users(nil, [sort_by: {"user_name", :desc}], [])
      assert Enum.map(users, & &1.user_name) == ["carol", "bob", "alice"]
    end

    test "applies pagination (start_index/count)" do
      {:ok, users, total} =
        StorageAdapter.list_users(nil, [sort_by: {"user_name", :asc}], start_index: 2, count: 1)

      assert total == 3
      assert Enum.map(users, & &1.user_name) == ["bob"]
    end

    test "an unresolvable filter attribute returns {:error, {:invalid_filter, _}}" do
      # The adapter logs the invalid filter at :warning - capture it to keep output clean.
      import ExUnit.CaptureLog

      capture_log(fn ->
        assert {:error, {:invalid_filter, _msg}} =
                 StorageAdapter.list_users({:eq, "totallyMadeUpField", "x"}, [], [])
      end)
    end
  end

  describe "list_groups" do
    setup do
      {:ok, _} = StorageAdapter.create_group(%{id: "g1", display_name: "Engineering"})
      {:ok, _} = StorageAdapter.create_group(%{id: "g2", display_name: "Sales"})
      :ok
    end

    test "returns all groups with a total count" do
      assert {:ok, groups, 2} = StorageAdapter.list_groups(nil, [], [])
      assert length(groups) == 2
    end

    test "applies a filter" do
      assert {:ok, [group], 1} =
               StorageAdapter.list_groups({:eq, "displayName", "Sales"}, [], [])

      assert group.display_name == "Sales"
    end

    test "applies sorting and pagination" do
      {:ok, groups, total} =
        StorageAdapter.list_groups(nil, [sort_by: {"display_name", :desc}],
          start_index: 1,
          count: 1
        )

      assert total == 2
      assert Enum.map(groups, & &1.display_name) == ["Sales"]
    end
  end

  describe "tenant isolation (tenant_key)" do
    test "create injects tenant_id and reads are scoped" do
      with_config(:user_model, {User, tenant_key: :organization_id}, fn ->
        scope_a = %Scope{id: "c", scopes: [], tenant_id: "org-a"}
        scope_b = %Scope{id: "c", scopes: [], tenant_id: "org-b"}

        {:ok, _} = StorageAdapter.create_user(user_attrs("ua", "alice"), scope_a)
        {:ok, _} = StorageAdapter.create_user(user_attrs("ub", "bob"), scope_b)

        # Each tenant only sees its own user
        assert {:ok, [%{user_name: "alice"}], 1} = StorageAdapter.list_users(nil, [], [], scope_a)
        assert {:ok, _ua} = StorageAdapter.get_user("ua", scope_a)
        assert {:error, :not_found} = StorageAdapter.get_user("ua", scope_b)
        refute StorageAdapter.user_exists?("ua", scope_b)
        assert StorageAdapter.user_exists?("ua", scope_a)
      end)
    end
  end

  describe "field_mapping (domain :active <-> db :status)" do
    test "writes transform to the db column and reads transform back (returns a map)" do
      mapping = %{
        active:
          {:status,
           fn
             true -> "active"
             false -> "inactive"
           end,
           fn
             "active" -> true
             _ -> false
           end}
      }

      with_config(:user_model, {ExScimEcto.TestSupport.UserStatus, field_mapping: mapping}, fn ->
        {:ok, _} = StorageAdapter.create_user(%{id: "u1", user_name: "alice", active: true})

        # Raw column stored the transformed value
        assert %{rows: [["active"]]} =
                 Ecto.Adapters.SQL.query!(
                   TestRepo,
                   "SELECT status FROM users WHERE id = 'u1'",
                   []
                 )

        # Read maps it back to the domain field; field_mapping makes get return a map
        assert {:ok, user} = StorageAdapter.get_user("u1")
        assert user.active == true
        refute Map.has_key?(user, :status)
      end)
    end
  end

  describe "preload (configured associations)" do
    test "get_user preloads the configured association" do
      with_config(:user_model, {User, preload: [:user_emails]}, fn ->
        {:ok, _} = StorageAdapter.create_user(user_attrs("u1", "alice"))
        TestRepo.insert!(%UserEmail{user_id: "u1", value: "alice@example.com", type: "work"})

        assert {:ok, user} = StorageAdapter.get_user("u1")
        assert [%UserEmail{value: "alice@example.com"}] = user.user_emails
      end)
    end
  end
end
