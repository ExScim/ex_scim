defmodule ExScim.Operations.UsersTest do
  use ExUnit.Case, async: false

  alias ExScim.Operations.Users

  import ExScim.TestFixtures

  @scope %ExScim.Scope{
    id: "test-client",
    scopes: ["scim:read", "scim:create", "scim:update", "scim:delete"]
  }

  setup do
    # Use test storage that works with atom-keyed domain maps
    {:ok, _} = ExScim.Operations.UsersTest.TestStorage.start_link()
    previous_storage = Application.get_env(:ex_scim, :storage_strategy)
    previous_lifecycle = Application.get_env(:ex_scim, :lifecycle_adapter)
    Application.put_env(:ex_scim, :storage_strategy, ExScim.Operations.UsersTest.TestStorage)
    Application.delete_env(:ex_scim, :lifecycle_adapter)

    on_exit(fn ->
      if previous_storage do
        Application.put_env(:ex_scim, :storage_strategy, previous_storage)
      else
        Application.delete_env(:ex_scim, :storage_strategy)
      end

      if previous_lifecycle do
        Application.put_env(:ex_scim, :lifecycle_adapter, previous_lifecycle)
      else
        Application.delete_env(:ex_scim, :lifecycle_adapter)
      end

      ExScim.Operations.UsersTest.TestStorage.stop()
    end)

    :ok
  end

  describe "get_user/2" do
    test "returns SCIM-formatted user for valid ID" do
      {:ok, created} = create_test_user()
      scim_id = created["id"]

      assert {:ok, scim_user} = Users.get_user(scim_id, @scope)
      assert scim_user["id"] == scim_id
      assert scim_user["userName"] == "john.doe"
      assert is_list(scim_user["schemas"])
      assert "urn:ietf:params:scim:schemas:core:2.0:User" in scim_user["schemas"]
    end

    test "returns error for missing user" do
      assert {:error, :not_found} = Users.get_user("nonexistent-id", @scope)
    end

    test "calls lifecycle before_get and after_get" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_user()
      Process.put(:lifecycle_calls, [])

      {:ok, _} = Users.get_user(created["id"], @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_get in hook_names
      assert :after_get in hook_names
    end

    test "lifecycle rejection halts get" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.RejectingLifecycle)
      {:ok, created} = create_test_user_bypassing_lifecycle()

      assert {:error, {:forbidden, _}} = Users.get_user(created["id"], @scope)
    end

    test "on_error called when get fails" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:error, :not_found} = Users.get_user("missing", @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :on_error in hook_names
    end
  end

  describe "list_users_scim/2" do
    test "returns SCIM list with users and total count" do
      {:ok, _} = create_test_user("alice")
      {:ok, _} = create_test_user("bob")

      assert {:ok, scim_users, 2} = Users.list_users_scim(@scope)
      assert length(scim_users) == 2
      assert Enum.all?(scim_users, &is_map/1)
      assert Enum.all?(scim_users, &Map.has_key?(&1, "userName"))
    end

    test "returns empty list when no users" do
      assert {:ok, [], 0} = Users.list_users_scim(@scope)
    end

    test "pagination params forwarded" do
      for i <- 1..5, do: create_test_user("user#{i}")

      assert {:ok, scim_users, 5} = Users.list_users_scim(@scope, %{start_index: 2, count: 2})
      assert length(scim_users) == 2
    end

    test "defaults to startIndex=1, count=20" do
      for i <- 1..3, do: create_test_user("user#{i}")

      assert {:ok, scim_users, 3} = Users.list_users_scim(@scope, %{})
      assert length(scim_users) == 3
    end

    test "all returned users are valid SCIM format" do
      {:ok, _} = create_test_user("alice")
      {:ok, _} = create_test_user("bob")

      {:ok, scim_users, _} = Users.list_users_scim(@scope)

      for user <- scim_users do
        assert is_binary(user["id"])
        assert is_binary(user["userName"])
        assert Map.has_key?(user, "schemas")
      end
    end
  end

  describe "create_user_from_scim/2" do
    test "creates user and returns SCIM representation" do
      scim_data = valid_scim_user_attrs()

      assert {:ok, scim_user} = Users.create_user_from_scim(scim_data, @scope)
      assert is_binary(scim_user["id"])
      assert scim_user["userName"] == "john.doe"
      assert scim_user["active"] == true
      assert "urn:ietf:params:scim:schemas:core:2.0:User" in scim_user["schemas"]
    end

    test "generates UUID when ID not provided" do
      scim_data = valid_scim_user_attrs() |> Map.delete("id")

      assert {:ok, scim_user} = Users.create_user_from_scim(scim_data, @scope)
      assert is_binary(scim_user["id"])
      assert String.match?(scim_user["id"], ~r/^[0-9a-f-]{36}$/)
    end

    test "preserves caller-supplied ID" do
      scim_data = valid_scim_user_attrs() |> Map.put("id", "custom-id-123")

      assert {:ok, scim_user} = Users.create_user_from_scim(scim_data, @scope)
      assert scim_user["id"] == "custom-id-123"
    end

    test "sets metadata timestamps" do
      scim_data = valid_scim_user_attrs()

      assert {:ok, scim_user} = Users.create_user_from_scim(scim_data, @scope)
      assert scim_user["meta"]["created"] != nil
      assert scim_user["meta"]["lastModified"] != nil
    end

    test "rejects missing required fields (userName)" do
      scim_data = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "name" => %{"givenName" => "No", "familyName" => "Username"}
      }

      assert {:error, _reason} = Users.create_user_from_scim(scim_data, @scope)
    end

    test "rejects missing schemas" do
      scim_data = %{"userName" => "no.schema"}

      assert {:error, _reason} = Users.create_user_from_scim(scim_data, @scope)
    end

    test "calls lifecycle before_create and after_create" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:ok, _} = Users.create_user_from_scim(valid_scim_user_attrs(), @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_create in hook_names
      assert :after_create in hook_names
    end

    test "lifecycle rejection short-circuits creation" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.RejectingLifecycle)

      assert {:error, {:forbidden, _}} =
               Users.create_user_from_scim(valid_scim_user_attrs(), @scope)

      # Verify user was NOT stored
      Application.delete_env(:ex_scim, :lifecycle_adapter)
      assert {:ok, [], 0} = Users.list_users_scim(@scope)
    end

    test "lifecycle can modify resource data before storage" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.ModifyingLifecycle)

      assert {:ok, _scim_user} = Users.create_user_from_scim(valid_scim_user_attrs(), @scope)

      # User was stored (lifecycle added :lifecycle_enriched internally)
      assert {:ok, [_], 1} = Users.list_users_scim(@scope)
    end

    test "stored user is retrievable by ID" do
      {:ok, created} = Users.create_user_from_scim(valid_scim_user_attrs(), @scope)

      assert {:ok, fetched} = Users.get_user(created["id"], @scope)
      assert fetched["userName"] == created["userName"]
      assert fetched["id"] == created["id"]
    end

    test "on_error called on create failure" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:error, _} = Users.create_user_from_scim(%{"userName" => "no-schema"}, @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :on_error in hook_names
    end
  end

  describe "replace_user_from_scim/3" do
    test "full PUT replace of existing user" do
      {:ok, created} = create_test_user()
      user_id = created["id"]

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "replaced.user",
        "name" => %{"givenName" => "Replaced", "familyName" => "User"},
        "active" => false
      }

      assert {:ok, replaced} = Users.replace_user_from_scim(user_id, replacement, @scope)
      assert replaced["id"] == user_id
      assert replaced["userName"] == "replaced.user"
      assert replaced["active"] == false
    end

    test "returns error for non-existent user" do
      replacement = valid_scim_user_attrs()

      assert {:error, :not_found} =
               Users.replace_user_from_scim("nonexistent", replacement, @scope)
    end

    test "preserves meta_created across replace" do
      {:ok, created} = create_test_user()
      user_id = created["id"]
      original_created = created["meta"]["created"]

      Process.sleep(10)

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "replaced.user",
        "name" => %{"givenName" => "Replaced", "familyName" => "User"}
      }

      assert {:ok, replaced} = Users.replace_user_from_scim(user_id, replacement, @scope)
      assert replaced["meta"]["created"] == original_created
    end

    test "updates meta_last_modified on replace" do
      {:ok, created} = create_test_user()
      user_id = created["id"]

      Process.sleep(10)

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "replaced.user",
        "name" => %{"givenName" => "Replaced", "familyName" => "User"}
      }

      assert {:ok, replaced} = Users.replace_user_from_scim(user_id, replacement, @scope)
      assert replaced["meta"]["lastModified"] != created["meta"]["lastModified"]
    end

    test "replaced user is retrievable with new data" do
      {:ok, created} = create_test_user()

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "replaced.user",
        "name" => %{"givenName" => "Replaced", "familyName" => "User"}
      }

      {:ok, _} = Users.replace_user_from_scim(created["id"], replacement, @scope)
      {:ok, fetched} = Users.get_user(created["id"], @scope)
      assert fetched["userName"] == "replaced.user"
    end

    test "calls lifecycle before_replace and after_replace" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_user()
      Process.put(:lifecycle_calls, [])

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName" => "replaced.user",
        "name" => %{"givenName" => "Replaced", "familyName" => "User"}
      }

      {:ok, _} = Users.replace_user_from_scim(created["id"], replacement, @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_replace in hook_names
      assert :after_replace in hook_names
    end

    test "rejects invalid schema in replacement payload" do
      {:ok, created} = create_test_user()

      invalid_replacement = %{"userName" => "no.schema"}

      assert {:error, _} =
               Users.replace_user_from_scim(created["id"], invalid_replacement, @scope)
    end
  end

  describe "patch_user_from_scim/3" do
    test "applies PATCH operations to existing user" do
      {:ok, created} = create_test_user()
      user_id = created["id"]

      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "display_name", "value" => "Patched Name"}
        ]
      }

      assert {:ok, patched} = Users.patch_user_from_scim(user_id, patch_data, @scope)
      assert patched["id"] == user_id
    end

    test "returns error for non-existent user" do
      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "displayName", "value" => "Patched"}
        ]
      }

      assert {:error, :not_found} =
               Users.patch_user_from_scim("nonexistent", patch_data, @scope)
    end

    test "updates metadata after patch" do
      {:ok, created} = create_test_user()
      user_id = created["id"]

      Process.sleep(10)

      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "user_name", "value" => "patched.user"}
        ]
      }

      assert {:ok, patched} = Users.patch_user_from_scim(user_id, patch_data, @scope)
      assert patched["meta"]["lastModified"] != created["meta"]["lastModified"]
    end

    test "calls lifecycle before_patch and after_patch" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_user()
      Process.put(:lifecycle_calls, [])

      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "user_name", "value" => "patched.user"}
        ]
      }

      {:ok, _} = Users.patch_user_from_scim(created["id"], patch_data, @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_patch in hook_names
      assert :after_patch in hook_names
    end
  end

  describe "delete_user/2" do
    test "deletes existing user" do
      {:ok, created} = create_test_user()
      user_id = created["id"]

      assert :ok = Users.delete_user(user_id, @scope)
      assert {:error, :not_found} = Users.get_user(user_id, @scope)
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = Users.delete_user("nonexistent", @scope)
    end

    test "calls lifecycle before_delete and after_delete" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_user()
      Process.put(:lifecycle_calls, [])

      :ok = Users.delete_user(created["id"], @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_delete in hook_names
      assert :after_delete in hook_names
    end

    test "lifecycle rejection halts delete" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.RejectingLifecycle)
      {:ok, created} = create_test_user_bypassing_lifecycle()

      assert {:error, {:forbidden, _}} = Users.delete_user(created["id"], @scope)

      # Verify user still exists
      Application.delete_env(:ex_scim, :lifecycle_adapter)
      assert {:ok, _} = Users.get_user(created["id"], @scope)
    end

    test "on_error called on delete failure" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:error, :not_found} = Users.delete_user("missing", @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :on_error in hook_names
    end
  end

  defp create_test_user(username \\ "john.doe") do
    scim_data = %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName" => username,
      "name" => %{"givenName" => "Test", "familyName" => "User"},
      "active" => true
    }

    Users.create_user_from_scim(scim_data, @scope)
  end

  # Creates user bypassing lifecycle (for tests where lifecycle rejects)
  defp create_test_user_bypassing_lifecycle(username \\ "john.doe") do
    previous = Application.get_env(:ex_scim, :lifecycle_adapter)
    Application.delete_env(:ex_scim, :lifecycle_adapter)

    result = create_test_user(username)

    if previous do
      Application.put_env(:ex_scim, :lifecycle_adapter, previous)
    end

    result
  end

  defmodule TestStorage do
    @behaviour ExScim.Storage.Adapter

    def start_link do
      case Agent.start_link(fn -> %{users: %{}, groups: %{}} end, name: __MODULE__) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
      end
    end

    def stop do
      case Process.whereis(__MODULE__) do
        nil -> :ok
        pid -> Agent.stop(pid)
      end
    end

    @impl true
    def get_user(user_id, _scope \\ nil) do
      case Agent.get(__MODULE__, &get_in(&1, [:users, user_id])) do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    end

    @impl true
    def list_users(filter_ast \\ nil, _sort_opts \\ [], pagination_opts \\ [], _scope \\ nil) do
      users = Agent.get(__MODULE__, &Map.values(&1.users))

      filtered =
        case filter_ast do
          nil -> users
          ast -> ExScim.QueryFilter.EtsQueryFilter.apply_filter(users, ast)
        end

      total = length(filtered)

      start_index = Keyword.get(pagination_opts, :start_index, 1)
      count = Keyword.get(pagination_opts, :count, 20)

      paginated =
        filtered
        |> Enum.drop(start_index - 1)
        |> Enum.take(count)

      {:ok, paginated, total}
    end

    @impl true
    def create_user(user_data, _scope \\ nil) do
      user_id = Map.get(user_data, :id) || Map.get(user_data, "id")

      Agent.update(__MODULE__, fn state ->
        put_in(state, [:users, user_id], user_data)
      end)

      {:ok, user_data}
    end

    @impl true
    def update_user(user_id, user_data, _scope \\ nil) do
      case get_user(user_id) do
        {:error, :not_found} ->
          {:error, :not_found}

        {:ok, _} ->
          Agent.update(__MODULE__, fn state ->
            put_in(state, [:users, user_id], user_data)
          end)

          {:ok, user_data}
      end
    end

    @impl true
    def replace_user(user_id, user_data, _scope \\ nil) do
      case get_user(user_id) do
        {:error, :not_found} ->
          {:error, :not_found}

        {:ok, _} ->
          Agent.update(__MODULE__, fn state ->
            put_in(state, [:users, user_id], user_data)
          end)

          {:ok, user_data}
      end
    end

    @impl true
    def delete_user(user_id, _scope \\ nil) do
      case get_user(user_id) do
        {:error, :not_found} ->
          {:error, :not_found}

        {:ok, _} ->
          Agent.update(__MODULE__, fn state ->
            update_in(state, [:users], &Map.delete(&1, user_id))
          end)

          :ok
      end
    end

    @impl true
    def user_exists?(user_id, _scope \\ nil) do
      case get_user(user_id) do
        {:ok, _} -> true
        _ -> false
      end
    end

    @impl true
    def get_group(group_id, _scope \\ nil) do
      case Agent.get(__MODULE__, &get_in(&1, [:groups, group_id])) do
        nil -> {:error, :not_found}
        group -> {:ok, group}
      end
    end

    @impl true
    def list_groups(_filter_ast \\ nil, _sort_opts \\ [], _pagination_opts \\ [], _scope \\ nil) do
      groups = Agent.get(__MODULE__, &Map.values(&1.groups))
      {:ok, groups, length(groups)}
    end

    @impl true
    def create_group(group_data, _scope \\ nil) do
      group_id = Map.get(group_data, :id) || Map.get(group_data, "id")

      Agent.update(__MODULE__, fn state ->
        put_in(state, [:groups, group_id], group_data)
      end)

      {:ok, group_data}
    end

    @impl true
    def update_group(group_id, group_data, _scope \\ nil) do
      Agent.update(__MODULE__, fn state ->
        put_in(state, [:groups, group_id], group_data)
      end)

      {:ok, group_data}
    end

    @impl true
    def replace_group(group_id, group_data, _scope \\ nil) do
      Agent.update(__MODULE__, fn state ->
        put_in(state, [:groups, group_id], group_data)
      end)

      {:ok, group_data}
    end

    @impl true
    def delete_group(group_id, _scope \\ nil) do
      case get_group(group_id) do
        {:error, :not_found} ->
          {:error, :not_found}

        {:ok, _} ->
          Agent.update(__MODULE__, fn state ->
            update_in(state, [:groups], &Map.delete(&1, group_id))
          end)

          :ok
      end
    end

    @impl true
    def group_exists?(group_id, _scope \\ nil) do
      case get_group(group_id) do
        {:ok, _} -> true
        _ -> false
      end
    end
  end
end
