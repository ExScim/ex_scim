defmodule ExScim.Test.TestLifecycle do
  @moduledoc """
  Test lifecycle adapter that records hook invocations via the process dictionary.

  Uses the calling process's dictionary to track which hooks were called
  and with what arguments, enabling assertions in tests.
  """
  use ExScim.Lifecycle.Adapter

  @impl true
  def before_create(resource_type, resource_data, caller) do
    record_call(:before_create, {resource_type, resource_data, caller})
    {:ok, resource_data}
  end

  @impl true
  def before_replace(resource_type, resource_id, resource_data, caller) do
    record_call(:before_replace, {resource_type, resource_id, resource_data, caller})
    {:ok, resource_data}
  end

  @impl true
  def before_patch(resource_type, resource_id, resource_data, caller) do
    record_call(:before_patch, {resource_type, resource_id, resource_data, caller})
    {:ok, resource_data}
  end

  @impl true
  def before_delete(resource_type, resource_id, caller) do
    record_call(:before_delete, {resource_type, resource_id, caller})
    :ok
  end

  @impl true
  def before_get(resource_type, resource_id, caller) do
    record_call(:before_get, {resource_type, resource_id, caller})
    :ok
  end

  @impl true
  def after_create(resource_type, scim_response, caller) do
    record_call(:after_create, {resource_type, scim_response, caller})
    :ok
  end

  @impl true
  def after_replace(resource_type, scim_response, caller) do
    record_call(:after_replace, {resource_type, scim_response, caller})
    :ok
  end

  @impl true
  def after_patch(resource_type, scim_response, caller) do
    record_call(:after_patch, {resource_type, scim_response, caller})
    :ok
  end

  @impl true
  def after_delete(resource_type, resource_id, caller) do
    record_call(:after_delete, {resource_type, resource_id, caller})
    :ok
  end

  @impl true
  def after_get(resource_type, scim_response, caller) do
    record_call(:after_get, {resource_type, scim_response, caller})
    :ok
  end

  @impl true
  def on_error(operation, resource_type, error, caller) do
    record_call(:on_error, {operation, resource_type, error, caller})
    :ok
  end

  defp record_call(hook_name, args) do
    calls = Process.get(:lifecycle_calls, [])
    Process.put(:lifecycle_calls, calls ++ [{hook_name, args}])
  end
end

defmodule ExScim.Test.RejectingLifecycle do
  @moduledoc "Lifecycle adapter that rejects all before hooks."
  use ExScim.Lifecycle.Adapter

  @impl true
  def before_create(_resource_type, _resource_data, _caller) do
    {:error, {:forbidden, "Rejected by lifecycle hook"}}
  end

  @impl true
  def before_replace(_resource_type, _resource_id, _resource_data, _caller) do
    {:error, {:forbidden, "Rejected by lifecycle hook"}}
  end

  @impl true
  def before_patch(_resource_type, _resource_id, _resource_data, _caller) do
    {:error, {:forbidden, "Rejected by lifecycle hook"}}
  end

  @impl true
  def before_delete(_resource_type, _resource_id, _caller) do
    {:error, {:forbidden, "Rejected by lifecycle hook"}}
  end

  @impl true
  def before_get(_resource_type, _resource_id, _caller) do
    {:error, {:forbidden, "Rejected by lifecycle hook"}}
  end
end

defmodule ExScim.Test.CrashingLifecycle do
  @moduledoc "Lifecycle adapter that crashes in all hooks."
  use ExScim.Lifecycle.Adapter

  @impl true
  def before_create(_resource_type, _resource_data, _caller) do
    raise "before_create crashed!"
  end

  @impl true
  def after_create(_resource_type, _scim_response, _caller) do
    raise "after_create crashed!"
  end

  @impl true
  def on_error(_operation, _resource_type, _error, _caller) do
    raise "on_error crashed!"
  end
end

defmodule ExScim.Test.ModifyingLifecycle do
  @moduledoc "Lifecycle adapter that modifies resource data in before hooks."
  use ExScim.Lifecycle.Adapter

  @impl true
  def before_create(_resource_type, resource_data, _caller) do
    {:ok, Map.put(resource_data, :lifecycle_enriched, true)}
  end

  @impl true
  def before_replace(_resource_type, _resource_id, resource_data, _caller) do
    {:ok, Map.put(resource_data, :lifecycle_enriched, true)}
  end

  @impl true
  def before_patch(_resource_type, _resource_id, resource_data, _caller) do
    {:ok, Map.put(resource_data, :lifecycle_enriched, true)}
  end
end
