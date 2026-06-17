defmodule ExScim.Operations.GroupsTest do
  use ExUnit.Case, async: false

  alias ExScim.Operations.Groups

  @scope %ExScim.Scope{
    id: "test-client",
    scopes: ["scim:read", "scim:create", "scim:update", "scim:delete"]
  }

  setup do
    # Use test storage that works with atom-keyed domain maps (see Operations.UsersTest)
    {:ok, _} = ExScim.Operations.GroupsTest.TestStorage.start_link()
    previous_storage = Application.get_env(:ex_scim, :storage_strategy)
    previous_lifecycle = Application.get_env(:ex_scim, :lifecycle_adapter)
    Application.put_env(:ex_scim, :storage_strategy, ExScim.Operations.GroupsTest.TestStorage)
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

      ExScim.Operations.GroupsTest.TestStorage.stop()
    end)

    :ok
  end

  describe "get_group/2" do
    test "returns SCIM-formatted group for valid ID" do
      {:ok, created} = create_test_group()
      scim_id = created["id"]

      assert {:ok, scim_group} = Groups.get_group(scim_id, @scope)
      assert scim_group["id"] == scim_id
      assert scim_group["displayName"] == "Engineering"
      assert is_list(scim_group["schemas"])
      assert "urn:ietf:params:scim:schemas:core:2.0:Group" in scim_group["schemas"]
    end

    test "returns error for missing group" do
      assert {:error, :not_found} = Groups.get_group("nonexistent-id", @scope)
    end

    test "calls lifecycle before_get and after_get" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_group()
      Process.put(:lifecycle_calls, [])

      {:ok, _} = Groups.get_group(created["id"], @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_get in hook_names
      assert :after_get in hook_names
    end

    test "lifecycle rejection halts get" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.RejectingLifecycle)
      {:ok, created} = create_test_group_bypassing_lifecycle()

      assert {:error, {:forbidden, _}} = Groups.get_group(created["id"], @scope)
    end

    test "on_error called when get fails" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:error, :not_found} = Groups.get_group("missing", @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :on_error in hook_names
    end
  end

  describe "list_groups_scim/2" do
    test "returns SCIM list with groups and total count" do
      {:ok, _} = create_test_group("Engineering")
      {:ok, _} = create_test_group("Sales")

      assert {:ok, scim_groups, 2} = Groups.list_groups_scim(@scope)
      assert length(scim_groups) == 2
      assert Enum.all?(scim_groups, &is_map/1)
      assert Enum.all?(scim_groups, &Map.has_key?(&1, "displayName"))
    end

    test "returns empty list when no groups" do
      assert {:ok, [], 0} = Groups.list_groups_scim(@scope)
    end

    test "pagination params forwarded" do
      for i <- 1..5, do: create_test_group("group#{i}")

      assert {:ok, scim_groups, 5} = Groups.list_groups_scim(@scope, %{start_index: 2, count: 2})
      assert length(scim_groups) == 2
    end

    test "defaults to startIndex=1, count=20" do
      for i <- 1..3, do: create_test_group("group#{i}")

      assert {:ok, scim_groups, 3} = Groups.list_groups_scim(@scope, %{})
      assert length(scim_groups) == 3
    end

    test "all returned groups are valid SCIM format" do
      {:ok, _} = create_test_group("Engineering")
      {:ok, _} = create_test_group("Sales")

      {:ok, scim_groups, _} = Groups.list_groups_scim(@scope)

      for group <- scim_groups do
        assert is_binary(group["id"])
        assert is_binary(group["displayName"])
        assert Map.has_key?(group, "schemas")
      end
    end
  end

  describe "create_group_from_scim/2" do
    test "creates group and returns SCIM representation" do
      assert {:ok, scim_group} = Groups.create_group_from_scim(valid_scim_group_attrs(), @scope)
      assert is_binary(scim_group["id"])
      assert scim_group["displayName"] == "Engineering"
      assert "urn:ietf:params:scim:schemas:core:2.0:Group" in scim_group["schemas"]
    end

    test "creates group with members list" do
      scim_data =
        valid_scim_group_attrs()
        |> Map.put("members", [
          %{"value" => "user-1", "display" => "Alice"},
          %{"value" => "user-2", "display" => "Bob"}
        ])

      assert {:ok, scim_group} = Groups.create_group_from_scim(scim_data, @scope)
      assert length(scim_group["members"]) == 2
      assert Enum.any?(scim_group["members"], &(&1["value"] == "user-1"))
    end

    test "generates UUID when ID not provided" do
      scim_data = valid_scim_group_attrs() |> Map.delete("id")

      assert {:ok, scim_group} = Groups.create_group_from_scim(scim_data, @scope)
      assert is_binary(scim_group["id"])
      assert String.match?(scim_group["id"], ~r/^[0-9a-f-]{36}$/)
    end

    test "preserves caller-supplied ID" do
      scim_data = valid_scim_group_attrs() |> Map.put("id", "custom-group-123")

      assert {:ok, scim_group} = Groups.create_group_from_scim(scim_data, @scope)
      assert scim_group["id"] == "custom-group-123"
    end

    test "sets metadata timestamps" do
      assert {:ok, scim_group} = Groups.create_group_from_scim(valid_scim_group_attrs(), @scope)
      assert scim_group["meta"]["created"] != nil
      assert scim_group["meta"]["lastModified"] != nil
    end

    test "rejects missing required field (displayName)" do
      scim_data = %{"schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"]}

      assert {:error, _reason} = Groups.create_group_from_scim(scim_data, @scope)
    end

    test "rejects missing schemas" do
      scim_data = %{"displayName" => "No Schema"}

      assert {:error, _reason} = Groups.create_group_from_scim(scim_data, @scope)
    end

    test "calls lifecycle before_create and after_create" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:ok, _} = Groups.create_group_from_scim(valid_scim_group_attrs(), @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_create in hook_names
      assert :after_create in hook_names
    end

    test "lifecycle rejection short-circuits creation" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.RejectingLifecycle)

      assert {:error, {:forbidden, _}} =
               Groups.create_group_from_scim(valid_scim_group_attrs(), @scope)

      # Verify group was NOT stored
      Application.delete_env(:ex_scim, :lifecycle_adapter)
      assert {:ok, [], 0} = Groups.list_groups_scim(@scope)
    end

    test "lifecycle can modify resource data before storage" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.ModifyingLifecycle)

      assert {:ok, _scim_group} = Groups.create_group_from_scim(valid_scim_group_attrs(), @scope)

      # Group was stored (lifecycle enriched data internally)
      assert {:ok, [_], 1} = Groups.list_groups_scim(@scope)
    end

    test "stored group is retrievable by ID" do
      {:ok, created} = Groups.create_group_from_scim(valid_scim_group_attrs(), @scope)

      assert {:ok, fetched} = Groups.get_group(created["id"], @scope)
      assert fetched["displayName"] == created["displayName"]
      assert fetched["id"] == created["id"]
    end

    test "on_error called on create failure" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:error, _} = Groups.create_group_from_scim(%{"displayName" => "no-schema"}, @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :on_error in hook_names
    end
  end

  describe "replace_group_from_scim/3" do
    test "full PUT replace of existing group" do
      {:ok, created} = create_test_group()
      group_id = created["id"]

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
        "displayName" => "Replaced Group",
        "members" => [%{"value" => "user-9", "display" => "Zara"}]
      }

      assert {:ok, replaced} = Groups.replace_group_from_scim(group_id, replacement, @scope)
      assert replaced["id"] == group_id
      assert replaced["displayName"] == "Replaced Group"
      assert Enum.any?(replaced["members"], &(&1["value"] == "user-9"))
    end

    test "returns error for non-existent group" do
      assert {:error, :not_found} =
               Groups.replace_group_from_scim("nonexistent", valid_scim_group_attrs(), @scope)
    end

    test "preserves meta_created across replace" do
      {:ok, created} = create_test_group()
      group_id = created["id"]
      original_created = created["meta"]["created"]

      Process.sleep(10)

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
        "displayName" => "Replaced Group"
      }

      assert {:ok, replaced} = Groups.replace_group_from_scim(group_id, replacement, @scope)
      assert replaced["meta"]["created"] == original_created
    end

    test "updates meta_last_modified on replace" do
      {:ok, created} = create_test_group()
      group_id = created["id"]

      Process.sleep(10)

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
        "displayName" => "Replaced Group"
      }

      assert {:ok, replaced} = Groups.replace_group_from_scim(group_id, replacement, @scope)
      assert replaced["meta"]["lastModified"] != created["meta"]["lastModified"]
    end

    test "replaced group is retrievable with new data" do
      {:ok, created} = create_test_group()

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
        "displayName" => "Replaced Group"
      }

      {:ok, _} = Groups.replace_group_from_scim(created["id"], replacement, @scope)
      {:ok, fetched} = Groups.get_group(created["id"], @scope)
      assert fetched["displayName"] == "Replaced Group"
    end

    test "calls lifecycle before_replace and after_replace" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_group()
      Process.put(:lifecycle_calls, [])

      replacement = %{
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
        "displayName" => "Replaced Group"
      }

      {:ok, _} = Groups.replace_group_from_scim(created["id"], replacement, @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_replace in hook_names
      assert :after_replace in hook_names
    end

    test "rejects invalid schema in replacement payload" do
      {:ok, created} = create_test_group()

      invalid_replacement = %{"displayName" => "no.schema"}

      assert {:error, _} =
               Groups.replace_group_from_scim(created["id"], invalid_replacement, @scope)
    end
  end

  describe "patch_group_from_scim/3" do
    test "applies PATCH operations to existing group" do
      {:ok, created} = create_test_group()
      group_id = created["id"]

      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "display_name", "value" => "Patched Name"}
        ]
      }

      assert {:ok, patched} = Groups.patch_group_from_scim(group_id, patch_data, @scope)
      assert patched["id"] == group_id
    end

    test "returns error for non-existent group" do
      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "displayName", "value" => "Patched"}
        ]
      }

      assert {:error, :not_found} =
               Groups.patch_group_from_scim("nonexistent", patch_data, @scope)
    end

    test "updates metadata after patch" do
      {:ok, created} = create_test_group()
      group_id = created["id"]

      Process.sleep(10)

      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "display_name", "value" => "Patched Name"}
        ]
      }

      assert {:ok, patched} = Groups.patch_group_from_scim(group_id, patch_data, @scope)
      assert patched["meta"]["lastModified"] != created["meta"]["lastModified"]
    end

    test "applies add member operation" do
      {:ok, created} = create_test_group()
      group_id = created["id"]

      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "add", "path" => "members", "value" => %{"value" => "user-new"}}
        ]
      }

      assert {:ok, patched} = Groups.patch_group_from_scim(group_id, patch_data, @scope)
      assert patched["id"] == group_id
    end

    test "calls lifecycle before_patch and after_patch" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_group()
      Process.put(:lifecycle_calls, [])

      patch_data = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [
          %{"op" => "replace", "path" => "display_name", "value" => "Patched Name"}
        ]
      }

      {:ok, _} = Groups.patch_group_from_scim(created["id"], patch_data, @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_patch in hook_names
      assert :after_patch in hook_names
    end
  end

  describe "delete_group/2" do
    test "deletes existing group" do
      {:ok, created} = create_test_group()
      group_id = created["id"]

      assert :ok = Groups.delete_group(group_id, @scope)
      assert {:error, :not_found} = Groups.get_group(group_id, @scope)
    end

    test "returns error for non-existent group" do
      assert {:error, :not_found} = Groups.delete_group("nonexistent", @scope)
    end

    test "calls lifecycle before_delete and after_delete" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      {:ok, created} = create_test_group()
      Process.put(:lifecycle_calls, [])

      :ok = Groups.delete_group(created["id"], @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :before_delete in hook_names
      assert :after_delete in hook_names
    end

    test "lifecycle rejection halts delete" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.RejectingLifecycle)
      {:ok, created} = create_test_group_bypassing_lifecycle()

      assert {:error, {:forbidden, _}} = Groups.delete_group(created["id"], @scope)

      # Verify group still exists
      Application.delete_env(:ex_scim, :lifecycle_adapter)
      assert {:ok, _} = Groups.get_group(created["id"], @scope)
    end

    test "on_error called on delete failure" do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      Process.put(:lifecycle_calls, [])

      {:error, :not_found} = Groups.delete_group("missing", @scope)

      calls = Process.get(:lifecycle_calls, [])
      hook_names = Enum.map(calls, &elem(&1, 0))
      assert :on_error in hook_names
    end
  end

  defp valid_scim_group_attrs do
    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
      "displayName" => "Engineering"
    }
  end

  defp create_test_group(display_name \\ "Engineering") do
    scim_data = %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
      "displayName" => display_name,
      "members" => [%{"value" => "user-1", "display" => "Alice"}]
    }

    Groups.create_group_from_scim(scim_data, @scope)
  end

  # Creates group bypassing lifecycle (for tests where lifecycle rejects)
  defp create_test_group_bypassing_lifecycle(display_name \\ "Engineering") do
    previous = Application.get_env(:ex_scim, :lifecycle_adapter)
    Application.delete_env(:ex_scim, :lifecycle_adapter)

    result = create_test_group(display_name)

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
    def get_group(group_id, _scope \\ nil) do
      case Agent.get(__MODULE__, &get_in(&1, [:groups, group_id])) do
        nil -> {:error, :not_found}
        group -> {:ok, group}
      end
    end

    @impl true
    def list_groups(filter_ast \\ nil, _sort_opts \\ [], pagination_opts \\ [], _scope \\ nil) do
      groups = Agent.get(__MODULE__, &Map.values(&1.groups))

      filtered =
        case filter_ast do
          nil -> groups
          ast -> ExScim.QueryFilter.EtsQueryFilter.apply_filter(groups, ast)
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
    def create_group(group_data, _scope \\ nil) do
      group_id = Map.get(group_data, :id) || Map.get(group_data, "id")

      Agent.update(__MODULE__, fn state ->
        put_in(state, [:groups, group_id], group_data)
      end)

      {:ok, group_data}
    end

    @impl true
    def update_group(group_id, group_data, _scope \\ nil) do
      case get_group(group_id) do
        {:error, :not_found} ->
          {:error, :not_found}

        {:ok, _} ->
          Agent.update(__MODULE__, fn state ->
            put_in(state, [:groups, group_id], group_data)
          end)

          {:ok, group_data}
      end
    end

    @impl true
    def replace_group(group_id, group_data, _scope \\ nil) do
      case get_group(group_id) do
        {:error, :not_found} ->
          {:error, :not_found}

        {:ok, _} ->
          Agent.update(__MODULE__, fn state ->
            put_in(state, [:groups, group_id], group_data)
          end)

          {:ok, group_data}
      end
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

    # --- User callbacks (unused by these tests, required by the behaviour) ---

    @impl true
    def get_user(user_id, _scope \\ nil) do
      case Agent.get(__MODULE__, &get_in(&1, [:users, user_id])) do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    end

    @impl true
    def list_users(_filter_ast \\ nil, _sort_opts \\ [], _pagination_opts \\ [], _scope \\ nil) do
      users = Agent.get(__MODULE__, &Map.values(&1.users))
      {:ok, users, length(users)}
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
      Agent.update(__MODULE__, fn state ->
        put_in(state, [:users, user_id], user_data)
      end)

      {:ok, user_data}
    end

    @impl true
    def replace_user(user_id, user_data, _scope \\ nil) do
      Agent.update(__MODULE__, fn state ->
        put_in(state, [:users, user_id], user_data)
      end)

      {:ok, user_data}
    end

    @impl true
    def delete_user(user_id, _scope \\ nil) do
      Agent.update(__MODULE__, fn state ->
        update_in(state, [:users], &Map.delete(&1, user_id))
      end)

      :ok
    end

    @impl true
    def user_exists?(user_id, _scope \\ nil) do
      case get_user(user_id) do
        {:ok, _} -> true
        _ -> false
      end
    end
  end
end
