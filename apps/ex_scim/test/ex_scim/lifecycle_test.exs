defmodule ExScim.LifecycleTest do
  use ExUnit.Case

  alias ExScim.Lifecycle

  @caller %ExScim.Auth.Principal{id: "test-user", scopes: ["scim:read", "scim:write"]}

  setup do
    # Clear any lifecycle calls from process dict
    Process.delete(:lifecycle_calls)
    # Store original config
    original = Application.get_env(:ex_scim, :lifecycle_adapter)

    on_exit(fn ->
      if original do
        Application.put_env(:ex_scim, :lifecycle_adapter, original)
      else
        Application.delete_env(:ex_scim, :lifecycle_adapter)
      end
    end)

    :ok
  end

  describe "no adapter configured (transparent no-op)" do
    setup do
      Application.delete_env(:ex_scim, :lifecycle_adapter)
      :ok
    end

    test "before_create passes through data" do
      assert {:ok, %{name: "test"}} = Lifecycle.before_create(:user, %{name: "test"}, @caller)
    end

    test "before_replace passes through data" do
      assert {:ok, %{name: "test"}} =
               Lifecycle.before_replace(:user, "id-1", %{name: "test"}, @caller)
    end

    test "before_patch passes through data" do
      assert {:ok, %{name: "test"}} =
               Lifecycle.before_patch(:user, "id-1", %{name: "test"}, @caller)
    end

    test "before_delete returns :ok" do
      assert :ok = Lifecycle.before_delete(:user, "id-1", @caller)
    end

    test "before_get returns :ok" do
      assert :ok = Lifecycle.before_get(:user, "id-1", @caller)
    end

    test "after_create returns :ok" do
      assert :ok = Lifecycle.after_create(:user, %{"id" => "1"}, @caller)
    end

    test "after_replace returns :ok" do
      assert :ok = Lifecycle.after_replace(:user, %{"id" => "1"}, @caller)
    end

    test "after_patch returns :ok" do
      assert :ok = Lifecycle.after_patch(:user, %{"id" => "1"}, @caller)
    end

    test "after_delete returns :ok" do
      assert :ok = Lifecycle.after_delete(:user, "id-1", @caller)
    end

    test "after_get returns :ok" do
      assert :ok = Lifecycle.after_get(:user, %{"id" => "1"}, @caller)
    end

    test "on_error returns :ok" do
      assert :ok = Lifecycle.on_error(:create, :user, {:error, :not_found}, @caller)
    end
  end

  describe "adapter with default no-op implementations" do
    setup do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.TestLifecycle)
      :ok
    end

    test "before_create calls adapter and returns data" do
      data = %{name: "test"}
      assert {:ok, ^data} = Lifecycle.before_create(:user, data, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:before_create, {:user, ^data, @caller}}] = calls
    end

    test "before_replace calls adapter and returns data" do
      data = %{name: "test"}
      assert {:ok, ^data} = Lifecycle.before_replace(:group, "id-1", data, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:before_replace, {:group, "id-1", ^data, @caller}}] = calls
    end

    test "before_patch calls adapter and returns data" do
      data = %{name: "test"}
      assert {:ok, ^data} = Lifecycle.before_patch(:user, "id-1", data, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:before_patch, {:user, "id-1", ^data, @caller}}] = calls
    end

    test "before_delete calls adapter" do
      assert :ok = Lifecycle.before_delete(:user, "id-1", @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:before_delete, {:user, "id-1", @caller}}] = calls
    end

    test "before_get calls adapter" do
      assert :ok = Lifecycle.before_get(:group, "id-1", @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:before_get, {:group, "id-1", @caller}}] = calls
    end

    test "after_create calls adapter" do
      response = %{"id" => "1"}
      Lifecycle.after_create(:user, response, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:after_create, {:user, ^response, @caller}}] = calls
    end

    test "after_replace calls adapter" do
      response = %{"id" => "1"}
      Lifecycle.after_replace(:user, response, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:after_replace, {:user, ^response, @caller}}] = calls
    end

    test "after_patch calls adapter" do
      response = %{"id" => "1"}
      Lifecycle.after_patch(:user, response, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:after_patch, {:user, ^response, @caller}}] = calls
    end

    test "after_delete calls adapter" do
      Lifecycle.after_delete(:user, "id-1", @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:after_delete, {:user, "id-1", @caller}}] = calls
    end

    test "after_get calls adapter" do
      response = %{"id" => "1"}
      Lifecycle.after_get(:group, response, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:after_get, {:group, ^response, @caller}}] = calls
    end

    test "on_error calls adapter" do
      error = {:error, :not_found}
      Lifecycle.on_error(:create, :user, error, @caller)

      calls = Process.get(:lifecycle_calls, [])
      assert [{:on_error, {:create, :user, ^error, @caller}}] = calls
    end

    test "resource_type :user is passed for user operations" do
      Lifecycle.before_create(:user, %{}, @caller)
      [{:before_create, {resource_type, _, _}}] = Process.get(:lifecycle_calls, [])
      assert resource_type == :user
    end

    test "resource_type :group is passed for group operations" do
      Lifecycle.before_create(:group, %{}, @caller)
      [{:before_create, {resource_type, _, _}}] = Process.get(:lifecycle_calls, [])
      assert resource_type == :group
    end
  end

  describe "before-hook rejection short-circuits the pipeline" do
    setup do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.RejectingLifecycle)
      :ok
    end

    test "before_create returns error from adapter" do
      assert {:error, {:forbidden, "Rejected by lifecycle hook"}} =
               Lifecycle.before_create(:user, %{}, @caller)
    end

    test "before_replace returns error from adapter" do
      assert {:error, {:forbidden, "Rejected by lifecycle hook"}} =
               Lifecycle.before_replace(:user, "id-1", %{}, @caller)
    end

    test "before_patch returns error from adapter" do
      assert {:error, {:forbidden, "Rejected by lifecycle hook"}} =
               Lifecycle.before_patch(:user, "id-1", %{}, @caller)
    end

    test "before_delete returns error from adapter" do
      assert {:error, {:forbidden, "Rejected by lifecycle hook"}} =
               Lifecycle.before_delete(:user, "id-1", @caller)
    end

    test "before_get returns error from adapter" do
      assert {:error, {:forbidden, "Rejected by lifecycle hook"}} =
               Lifecycle.before_get(:user, "id-1", @caller)
    end
  end

  describe "hook crash handling" do
    setup do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.CrashingLifecycle)
      :ok
    end

    test "before hook crash fails closed with {:error, :lifecycle_hook_error}" do
      assert {:error, :lifecycle_hook_error} = Lifecycle.before_create(:user, %{}, @caller)
    end

    test "after hook crash fails open (returns :ok)" do
      assert :ok = Lifecycle.after_create(:user, %{"id" => "1"}, @caller)
    end

    test "on_error crash fails open (returns :ok)" do
      assert :ok = Lifecycle.on_error(:create, :user, {:error, :test}, @caller)
    end
  end

  describe "adapter module with __using__ macro" do
    test "default implementations are no-ops that pass through data" do
      defmodule DefaultAdapter do
        use ExScim.Lifecycle.Adapter
      end

      assert {:ok, %{data: 1}} = DefaultAdapter.before_create(:user, %{data: 1}, @caller)
      assert {:ok, %{data: 1}} = DefaultAdapter.before_replace(:user, "id", %{data: 1}, @caller)
      assert {:ok, %{data: 1}} = DefaultAdapter.before_patch(:user, "id", %{data: 1}, @caller)
      assert :ok = DefaultAdapter.before_delete(:user, "id", @caller)
      assert :ok = DefaultAdapter.before_get(:user, "id", @caller)
      assert :ok = DefaultAdapter.after_create(:user, %{}, @caller)
      assert :ok = DefaultAdapter.after_replace(:user, %{}, @caller)
      assert :ok = DefaultAdapter.after_patch(:user, %{}, @caller)
      assert :ok = DefaultAdapter.after_delete(:user, "id", @caller)
      assert :ok = DefaultAdapter.after_get(:user, %{}, @caller)
      assert :ok = DefaultAdapter.on_error(:create, :user, {:error, :test}, @caller)
    end

    test "callbacks are overridable" do
      defmodule CustomAdapter do
        use ExScim.Lifecycle.Adapter

        @impl true
        def before_create(:user, data, _caller) do
          {:ok, Map.put(data, :custom, true)}
        end
      end

      assert {:ok, %{name: "test", custom: true}} =
               CustomAdapter.before_create(:user, %{name: "test"}, @caller)

      # Non-overridden callbacks still work as defaults
      assert :ok = CustomAdapter.before_delete(:user, "id", @caller)
    end
  end

  describe "data modification in before hooks" do
    setup do
      Application.put_env(:ex_scim, :lifecycle_adapter, ExScim.Test.ModifyingLifecycle)
      :ok
    end

    test "before_create modification propagates" do
      {:ok, result} = Lifecycle.before_create(:user, %{name: "test"}, @caller)
      assert result.lifecycle_enriched == true
      assert result.name == "test"
    end

    test "before_replace modification propagates" do
      {:ok, result} = Lifecycle.before_replace(:user, "id-1", %{name: "test"}, @caller)
      assert result.lifecycle_enriched == true
    end

    test "before_patch modification propagates" do
      {:ok, result} = Lifecycle.before_patch(:user, "id-1", %{name: "test"}, @caller)
      assert result.lifecycle_enriched == true
    end
  end
end
