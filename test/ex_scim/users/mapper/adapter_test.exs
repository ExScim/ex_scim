defmodule ExScim.Users.Mapper.AdapterTest do
  use ExUnit.Case, async: true

  defmodule TestMapper do
    use ExScim.Users.Mapper.Adapter

    @impl true
    def from_scim(data), do: data

    @impl true
    def to_scim(user, opts), do: %{"meta" => format_meta(user, opts)}
  end

  defmodule CustomTimestampMapper do
    use ExScim.Users.Mapper.Adapter

    def get_meta_created(user), do: user.inserted_at
    def get_meta_last_modified(user), do: user.updated_at

    @impl true
    def from_scim(data), do: data

    @impl true
    def to_scim(user, opts), do: %{"meta" => format_meta(user, opts)}
  end

  defmodule VersionCounterMapper do
    use ExScim.Users.Mapper.Adapter

    def get_meta_version(user), do: "\"#{user.version}\""

    @impl true
    def from_scim(data), do: data

    @impl true
    def to_scim(user, opts), do: %{"meta" => format_meta(user, opts)}
  end

  describe "default implementations" do
    test "extracts meta_created and meta_last_modified" do
      now = DateTime.utc_now()
      user = %{meta_created: now, meta_last_modified: now}

      assert TestMapper.get_meta_created(user) == now
      assert TestMapper.get_meta_last_modified(user) == now
    end

    test "returns nil for missing timestamps" do
      user = %{}

      assert TestMapper.get_meta_created(user) == nil
      assert TestMapper.get_meta_last_modified(user) == nil
    end

    test "generates weak ETag from lastModified" do
      now = DateTime.utc_now()
      user = %{meta_last_modified: now}

      version = TestMapper.get_meta_version(user)
      assert version =~ ~r/^W\/"[a-f0-9]+\"$/
    end

    test "returns nil version when no lastModified" do
      user = %{meta_last_modified: nil}

      assert TestMapper.get_meta_version(user) == nil
    end

    test "format_meta produces RFC 7643 compliant structure" do
      now = DateTime.utc_now()
      user = %{meta_created: now, meta_last_modified: now}

      meta = TestMapper.format_meta(user, location: "https://example.com/Users/123")

      assert meta["resourceType"] == "User"
      assert meta["created"] == DateTime.to_iso8601(now)
      assert meta["lastModified"] == DateTime.to_iso8601(now)
      assert meta["location"] == "https://example.com/Users/123"
      assert meta["version"] =~ ~r/^W\/"[a-f0-9]+\"$/
    end

    test "format_meta omits nil values" do
      user = %{meta_created: nil, meta_last_modified: nil}

      meta = TestMapper.format_meta(user, [])

      assert meta["resourceType"] == "User"
      refute Map.has_key?(meta, "created")
      refute Map.has_key?(meta, "lastModified")
      refute Map.has_key?(meta, "location")
      refute Map.has_key?(meta, "version")
    end

    test "format_meta uses custom resource_type from opts" do
      user = %{meta_created: nil, meta_last_modified: nil}

      meta = TestMapper.format_meta(user, resource_type: "CustomUser")

      assert meta["resourceType"] == "CustomUser"
    end
  end

  describe "utility functions" do
    test "format_datetime handles DateTime" do
      dt = ~U[2024-01-15 10:30:00Z]
      assert TestMapper.format_datetime(dt) == "2024-01-15T10:30:00Z"
    end

    test "format_datetime handles nil" do
      assert TestMapper.format_datetime(nil) == nil
    end

    test "format_datetime passes through strings" do
      assert TestMapper.format_datetime("2024-01-15T10:30:00Z") == "2024-01-15T10:30:00Z"
    end

    test "parse_datetime handles ISO8601 string" do
      result = TestMapper.parse_datetime("2024-01-15T10:30:00Z")
      assert result == ~U[2024-01-15 10:30:00Z]
    end

    test "parse_datetime handles nil" do
      assert TestMapper.parse_datetime(nil) == nil
    end

    test "parse_datetime handles DateTime passthrough" do
      dt = ~U[2024-01-15 10:30:00Z]
      assert TestMapper.parse_datetime(dt) == dt
    end

    test "parse_datetime returns nil for invalid string" do
      assert TestMapper.parse_datetime("not a date") == nil
    end
  end

  describe "custom timestamp fields" do
    test "uses overridden extractors" do
      now = DateTime.utc_now()
      user = %{inserted_at: now, updated_at: now}

      assert CustomTimestampMapper.get_meta_created(user) == now
      assert CustomTimestampMapper.get_meta_last_modified(user) == now
    end

    test "format_meta uses overridden extractors" do
      now = DateTime.utc_now()
      user = %{inserted_at: now, updated_at: now}

      meta = CustomTimestampMapper.format_meta(user, [])

      assert meta["created"] == DateTime.to_iso8601(now)
      assert meta["lastModified"] == DateTime.to_iso8601(now)
    end

    test "version is derived from overridden lastModified" do
      now = DateTime.utc_now()
      user = %{inserted_at: now, updated_at: now}

      version = CustomTimestampMapper.get_meta_version(user)
      assert version =~ ~r/^W\/"[a-f0-9]+\"$/
    end
  end

  describe "custom version strategy" do
    test "uses version counter" do
      user = %{version: 42, meta_last_modified: nil}

      assert VersionCounterMapper.get_meta_version(user) == "\"42\""
    end

    test "format_meta uses custom version" do
      user = %{version: 42, meta_created: nil, meta_last_modified: nil}

      meta = VersionCounterMapper.format_meta(user, [])

      assert meta["version"] == "\"42\""
    end
  end

  describe "version determinism" do
    test "same timestamp produces same version" do
      dt = ~U[2024-01-15 10:30:00.000000Z]
      user1 = %{meta_last_modified: dt}
      user2 = %{meta_last_modified: dt}

      assert TestMapper.get_meta_version(user1) == TestMapper.get_meta_version(user2)
    end

    test "different timestamps produce different versions" do
      user1 = %{meta_last_modified: ~U[2024-01-15 10:30:00Z]}
      user2 = %{meta_last_modified: ~U[2024-01-15 10:30:01Z]}

      refute TestMapper.get_meta_version(user1) == TestMapper.get_meta_version(user2)
    end
  end
end
