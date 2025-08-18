defmodule ExScim.Resources.Metadata do
  @moduledoc """
  Handles SCIM metadata timestamps for resources.
  """

  @doc """
  Updates metadata timestamps on a resource.

  Sets meta_last_modified to current time, and meta_created if it's nil.
  Optionally sets meta_resource_type if provided.

  ## Parameters

    * `resource` - Domain struct with metadata fields
    * `resource_type` - Optional resource type (e.g., "User", "Group")
    
  ## Returns

    * Updated resource with current metadata timestamps
  """
  def update_metadata(resource, resource_type \\ nil) do
    now = DateTime.utc_now()

    resource
    |> maybe_set_created(now)
    |> Map.put(:meta_last_modified, now)
    |> maybe_set_resource_type(resource_type)
  end

  defp maybe_set_created(%{meta_created: nil} = resource, now) do
    Map.put(resource, :meta_created, now)
  end

  defp maybe_set_created(resource, _now), do: resource

  defp maybe_set_resource_type(resource, nil), do: resource

  defp maybe_set_resource_type(resource, resource_type) when is_binary(resource_type) do
    if Map.has_key?(resource, :meta_resource_type) do
      Map.put(resource, :meta_resource_type, resource_type)
    else
      resource
    end
  end
end
