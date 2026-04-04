defmodule ExScim.Resources.Metadata do
  @moduledoc """
  Handles SCIM metadata for resources: timestamping domain structs and
  computing/formatting the SCIM `meta` object (including ETag/version).
  """

  @doc """
  Updates metadata timestamps on a resource.

  Sets meta_last_modified to current time, and meta_created if it's nil.
  Optionally sets meta_resource_type if provided.
  """
  def update_metadata(resource, resource_type \\ nil) do
    now = DateTime.utc_now()

    resource
    |> maybe_set_created(now)
    |> Map.put(:meta_last_modified, now)
    |> maybe_set_resource_type(resource_type)
  end

  @doc """
  Computes a weak ETag version string given a raw version value and last-modified timestamp.

  If `version_value` is non-nil, it is stringified and hashed. Otherwise `last_modified`
  is used as the input. Returns `nil` if both are nil/unavailable.
  """
  def compute_version(version_value, last_modified \\ nil)

  def compute_version(nil, %DateTime{} = dt) do
    etag(DateTime.to_iso8601(dt))
  end

  def compute_version(nil, _), do: nil

  def compute_version(v, _) do
    etag(to_string(v))
  end

  @doc """
  Assembles the SCIM `meta` JSON object from pre-extracted values.

  `created` and `last_modified` may be `DateTime` structs or ISO 8601 strings.
  `version`, `location`, and `resource_type` may be nil (keys are omitted when nil).
  """
  def build_meta(created, last_modified, version, location, resource_type) do
    %{
      "resourceType" => resource_type,
      "created" => format_datetime(created),
      "lastModified" => format_datetime(last_modified),
      "location" => location,
      "version" => version
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc "Formats a DateTime to ISO 8601 string, passes binaries through, returns nil for nil."
  def format_datetime(nil), do: nil
  def format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def format_datetime(binary) when is_binary(binary), do: binary

  @doc "Parses an ISO 8601 string into a DateTime, passes DateTime through, returns nil for nil."
  def parse_datetime(nil), do: nil
  def parse_datetime(%DateTime{} = dt), do: dt

  def parse_datetime(binary) when is_binary(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> nil
    end
  end

  defp etag(str) do
    hash = str |> then(&:crypto.hash(:md5, &1)) |> Base.encode16(case: :lower)
    "W/\"#{hash}\""
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
