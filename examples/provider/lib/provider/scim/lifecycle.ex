defmodule Provider.Scim.Lifecycle do
  @moduledoc """
  Example lifecycle adapter for SCIM operations.

  Demonstrates how to use lifecycle hooks for audit logging.
  """
  use ExScim.Lifecycle.Adapter

  require Logger

  @impl true
  def after_create(resource_type, scim_response, caller) do
    Logger.info(
      "[SCIM Lifecycle] #{caller.id} created #{resource_type} #{scim_response["id"]}"
    )

    :ok
  end

  @impl true
  def after_replace(resource_type, scim_response, caller) do
    Logger.info(
      "[SCIM Lifecycle] #{caller.id} replaced #{resource_type} #{scim_response["id"]}"
    )

    :ok
  end

  @impl true
  def after_patch(resource_type, scim_response, caller) do
    Logger.info(
      "[SCIM Lifecycle] #{caller.id} patched #{resource_type} #{scim_response["id"]}"
    )

    :ok
  end

  @impl true
  def after_delete(resource_type, resource_id, caller) do
    Logger.info(
      "[SCIM Lifecycle] #{caller.id} deleted #{resource_type} #{resource_id}"
    )

    :ok
  end

  @impl true
  def on_error(operation, resource_type, error, caller) do
    Logger.warning(
      "[SCIM Lifecycle] #{caller.id} failed #{operation} on #{resource_type}: #{inspect(error)}"
    )

    :ok
  end
end
