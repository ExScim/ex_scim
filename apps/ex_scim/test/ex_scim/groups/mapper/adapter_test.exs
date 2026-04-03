defmodule ExScim.Groups.Mapper.AdapterTest do
  use ExUnit.Case, async: true

  defmodule TestMapper do
    use ExScim.Groups.Mapper.Adapter

    @impl true
    def from_scim(data, _caller), do: {:ok, data}

    @impl true
    def to_scim(group, _caller, opts), do: {:ok, %{"meta" => format_meta(group, opts)}}
  end

  defmodule CustomTimestampMapper do
    use ExScim.Groups.Mapper.Adapter

    def get_meta_created(group), do: group.inserted_at
    def get_meta_last_modified(group), do: group.updated_at

    @impl true
    def from_scim(data, _caller), do: {:ok, data}

    @impl true
    def to_scim(group, _caller, opts), do: {:ok, %{"meta" => format_meta(group, opts)}}
  end

  describe "default implementations" do
    test "extracts meta_created and meta_last_modified" do
      now = DateTime.utc_now()
      group = %{meta_created: now, meta_last_modified: now}

      assert TestMapper.get_meta_created(group) == now
      assert TestMapper.get_meta_last_modified(group) == now
    end

    test "generates weak ETag from lastModified" do
      now = DateTime.utc_now()
      group = %{meta_last_modified: now}

      version = TestMapper.get_meta_version(group)
      assert version =~ ~r/^W\/"[a-f0-9]+\"$/
    end

    test "uses meta_version field when present instead of lastModified" do
      now = DateTime.utc_now()
      group = %{meta_version: "v7", meta_last_modified: now}

      version = TestMapper.get_meta_version(group)
      assert version =~ ~r/^W\/"[a-f0-9]+\"$/

      timestamp_version = TestMapper.get_meta_version(%{meta_last_modified: now})
      assert version != timestamp_version
    end

    test "meta_version produces deterministic ETag independent of lastModified" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 3600)

      v1 = TestMapper.get_meta_version(%{meta_version: "rev-3", meta_last_modified: now})
      v2 = TestMapper.get_meta_version(%{meta_version: "rev-3", meta_last_modified: later})

      assert v1 == v2
    end

    test "different meta_version values produce different ETags" do
      now = DateTime.utc_now()

      v1 = TestMapper.get_meta_version(%{meta_version: "rev-1", meta_last_modified: now})
      v2 = TestMapper.get_meta_version(%{meta_version: "rev-2", meta_last_modified: now})

      assert v1 != v2
    end

    test "format_meta defaults to Group resource type" do
      group = %{meta_created: nil, meta_last_modified: nil}

      meta = TestMapper.format_meta(group, [])

      assert meta["resourceType"] == "Group"
    end

    test "format_meta produces RFC 7643 compliant structure" do
      now = DateTime.utc_now()
      group = %{meta_created: now, meta_last_modified: now}

      meta = TestMapper.format_meta(group, location: "https://example.com/Groups/456")

      assert meta["resourceType"] == "Group"
      assert meta["created"] == DateTime.to_iso8601(now)
      assert meta["lastModified"] == DateTime.to_iso8601(now)
      assert meta["location"] == "https://example.com/Groups/456"
      assert meta["version"] =~ ~r/^W\/"[a-f0-9]+\"$/
    end
  end

  describe "custom timestamp fields" do
    test "uses overridden extractors" do
      now = DateTime.utc_now()
      group = %{inserted_at: now, updated_at: now}

      assert CustomTimestampMapper.get_meta_created(group) == now
      assert CustomTimestampMapper.get_meta_last_modified(group) == now
    end

    test "format_meta uses overridden extractors" do
      now = DateTime.utc_now()
      group = %{inserted_at: now, updated_at: now}

      meta = CustomTimestampMapper.format_meta(group, [])

      assert meta["created"] == DateTime.to_iso8601(now)
      assert meta["lastModified"] == DateTime.to_iso8601(now)
    end
  end
end
