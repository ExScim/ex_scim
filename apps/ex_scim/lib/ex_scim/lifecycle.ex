defmodule ExScim.Lifecycle do
  @moduledoc """
  Facade for lifecycle hooks around SCIM operations.

  Delegates to the configured `lifecycle_adapter`. When no adapter is configured,
  all hooks are transparent no-ops.

  ## Error handling

  - **Before hooks** fail closed: crashes are rescued and return `{:error, :lifecycle_hook_error}`,
    rejecting the operation.
  - **After hooks** fail open: crashes are rescued and logged, the already-completed
    operation is returned as successful.
  - **on_error** crashes are silently rescued and logged.
  """

  require Logger

  # Before hooks: fail closed

  @doc "Fires before a resource is created. Returns `{:ok, data}` to proceed or `{:error, reason}` to halt."
  def before_create(resource_type, resource_data, caller) do
    case adapter() do
      nil -> {:ok, resource_data}
      mod -> safe_before(fn -> mod.before_create(resource_type, resource_data, caller) end)
    end
  end

  @doc "Fires before a resource is replaced (PUT). Returns `{:ok, data}` to proceed or `{:error, reason}` to halt."
  def before_replace(resource_type, resource_id, resource_data, caller) do
    case adapter() do
      nil ->
        {:ok, resource_data}

      mod ->
        safe_before(fn ->
          mod.before_replace(resource_type, resource_id, resource_data, caller)
        end)
    end
  end

  @doc "Fires before a resource is patched. Returns `{:ok, data}` to proceed or `{:error, reason}` to halt."
  def before_patch(resource_type, resource_id, resource_data, caller) do
    case adapter() do
      nil ->
        {:ok, resource_data}

      mod ->
        safe_before(fn -> mod.before_patch(resource_type, resource_id, resource_data, caller) end)
    end
  end

  @doc "Fires before a resource is deleted. Returns `:ok` to proceed or `{:error, reason}` to halt."
  def before_delete(resource_type, resource_id, caller) do
    case adapter() do
      nil -> :ok
      mod -> safe_before_action(fn -> mod.before_delete(resource_type, resource_id, caller) end)
    end
  end

  @doc "Fires before a resource is retrieved. Returns `:ok` to proceed or `{:error, reason}` to halt."
  def before_get(resource_type, resource_id, caller) do
    case adapter() do
      nil -> :ok
      mod -> safe_before_action(fn -> mod.before_get(resource_type, resource_id, caller) end)
    end
  end

  # After hooks: fail open

  @doc "Fires after a resource is successfully created. Observe-only; crashes are logged and swallowed."
  def after_create(resource_type, scim_response, caller) do
    safe_after(fn ->
      case adapter() do
        nil -> :ok
        mod -> mod.after_create(resource_type, scim_response, caller)
      end
    end)
  end

  @doc "Fires after a resource is successfully replaced. Observe-only."
  def after_replace(resource_type, scim_response, caller) do
    safe_after(fn ->
      case adapter() do
        nil -> :ok
        mod -> mod.after_replace(resource_type, scim_response, caller)
      end
    end)
  end

  @doc "Fires after a resource is successfully patched. Observe-only."
  def after_patch(resource_type, scim_response, caller) do
    safe_after(fn ->
      case adapter() do
        nil -> :ok
        mod -> mod.after_patch(resource_type, scim_response, caller)
      end
    end)
  end

  @doc "Fires after a resource is successfully deleted. Observe-only."
  def after_delete(resource_type, resource_id, caller) do
    safe_after(fn ->
      case adapter() do
        nil -> :ok
        mod -> mod.after_delete(resource_type, resource_id, caller)
      end
    end)
  end

  @doc "Fires after a resource is successfully retrieved. Observe-only."
  def after_get(resource_type, scim_response, caller) do
    safe_after(fn ->
      case adapter() do
        nil -> :ok
        mod -> mod.after_get(resource_type, scim_response, caller)
      end
    end)
  end

  # Error hook: fail open

  @doc "Fires when an operation fails. Observe-only; intended for logging or metrics."
  def on_error(operation, resource_type, error, caller) do
    safe_after(fn ->
      case adapter() do
        nil -> :ok
        mod -> mod.on_error(operation, resource_type, error, caller)
      end
    end)
  end

  @doc "Returns the configured lifecycle adapter module, or `nil` if none is configured."
  def adapter do
    Application.get_env(:ex_scim, :lifecycle_adapter)
  end

  # Before hooks fail closed: crash → {:error, :lifecycle_hook_error}
  defp safe_before(fun) do
    fun.()
  rescue
    error ->
      Logger.error(
        "Lifecycle before hook crashed: #{Exception.message(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      {:error, :lifecycle_hook_error}
  end

  # Before hooks for actions that return :ok | {:error, _} (delete, get)
  defp safe_before_action(fun) do
    fun.()
  rescue
    error ->
      Logger.error(
        "Lifecycle before hook crashed: #{Exception.message(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      {:error, :lifecycle_hook_error}
  end

  # After hooks fail open: crash → log and return :ok
  defp safe_after(fun) do
    fun.()
    :ok
  rescue
    error ->
      Logger.error(
        "Lifecycle after hook crashed: #{Exception.message(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      :ok
  end
end
