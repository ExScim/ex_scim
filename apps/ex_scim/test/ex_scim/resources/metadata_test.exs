defmodule ExScim.Resources.MetadataTest do
  use ExUnit.Case, async: true

  alias ExScim.Resources.Metadata

  describe "format_datetime/1" do
    test "formats DateTime to ISO 8601 string" do
      dt = ~U[2024-06-15 10:30:00Z]
      assert Metadata.format_datetime(dt) == "2024-06-15T10:30:00Z"
    end

    test "passes binary strings through unchanged" do
      str = "2024-06-15T10:30:00Z"
      assert Metadata.format_datetime(str) == str
    end

    test "returns nil for nil" do
      assert Metadata.format_datetime(nil) == nil
    end
  end

  describe "parse_datetime/1" do
    test "parses ISO 8601 string to DateTime" do
      assert %DateTime{year: 2024, month: 6, day: 15} =
               Metadata.parse_datetime("2024-06-15T10:30:00Z")
    end

    test "passes DateTime structs through unchanged" do
      dt = ~U[2024-06-15 10:30:00Z]
      assert Metadata.parse_datetime(dt) == dt
    end

    test "returns nil for nil" do
      assert Metadata.parse_datetime(nil) == nil
    end

    test "returns nil for invalid string" do
      assert Metadata.parse_datetime("not-a-date") == nil
    end

    test "returns nil for empty string" do
      assert Metadata.parse_datetime("") == nil
    end
  end

  describe "format/parse roundtrip" do
    test "DateTime survives format then parse" do
      dt = ~U[2024-06-15 10:30:00Z]
      assert Metadata.parse_datetime(Metadata.format_datetime(dt)) == dt
    end

    test "ISO 8601 string survives parse then format" do
      str = "2024-06-15T10:30:00Z"
      assert Metadata.format_datetime(Metadata.parse_datetime(str)) == str
    end
  end

  describe "compute_version/2" do
    test "returns weak ETag string for a version value" do
      etag = Metadata.compute_version("abc123")
      assert etag =~ ~r/^W\/"[0-9a-f]+"$/
    end

    test "is deterministic - same input produces same ETag" do
      a = Metadata.compute_version("abc123")
      b = Metadata.compute_version("abc123")
      assert a == b
    end

    test "different inputs produce different ETags" do
      a = Metadata.compute_version("abc")
      b = Metadata.compute_version("xyz")
      assert a != b
    end

    test "falls back to last_modified when version_value is nil" do
      dt = ~U[2024-06-15 10:30:00Z]
      etag = Metadata.compute_version(nil, dt)
      assert etag =~ ~r/^W\/"[0-9a-f]+"$/
    end

    test "returns nil when both version_value and last_modified are nil" do
      assert Metadata.compute_version(nil, nil) == nil
    end

    test "returns nil when version_value is nil and last_modified is not a DateTime" do
      assert Metadata.compute_version(nil, "not-a-datetime") == nil
    end

    test "stringifies non-string version values" do
      etag = Metadata.compute_version(42)
      assert etag =~ ~r/^W\/"[0-9a-f]+"$/
    end
  end

  describe "build_meta/5" do
    test "constructs meta map with all fields present" do
      meta =
        Metadata.build_meta(
          ~U[2024-01-01 00:00:00Z],
          ~U[2024-06-15 10:30:00Z],
          "W/\"abc\"",
          "https://example.com/Users/123",
          "User"
        )

      assert meta["resourceType"] == "User"
      assert meta["created"] == "2024-01-01T00:00:00Z"
      assert meta["lastModified"] == "2024-06-15T10:30:00Z"
      assert meta["version"] == "W/\"abc\""
      assert meta["location"] == "https://example.com/Users/123"
    end

    test "omits nil values from the output" do
      meta =
        Metadata.build_meta(~U[2024-01-01 00:00:00Z], ~U[2024-06-15 10:30:00Z], nil, nil, nil)

      refute Map.has_key?(meta, "resourceType")
      refute Map.has_key?(meta, "version")
      refute Map.has_key?(meta, "location")
      assert Map.has_key?(meta, "created")
      assert Map.has_key?(meta, "lastModified")
    end

    test "accepts pre-formatted string timestamps" do
      meta =
        Metadata.build_meta(
          "2024-01-01T00:00:00Z",
          "2024-06-15T10:30:00Z",
          nil,
          nil,
          nil
        )

      assert meta["created"] == "2024-01-01T00:00:00Z"
      assert meta["lastModified"] == "2024-06-15T10:30:00Z"
    end
  end

  describe "update_metadata/2" do
    test "sets meta_created when nil" do
      resource = %{meta_created: nil, meta_last_modified: nil}
      updated = Metadata.update_metadata(resource)

      assert %DateTime{} = updated.meta_created
      assert %DateTime{} = updated.meta_last_modified
    end

    test "preserves existing meta_created" do
      original_created = ~U[2024-01-01 00:00:00Z]
      resource = %{meta_created: original_created, meta_last_modified: nil}
      updated = Metadata.update_metadata(resource)

      assert updated.meta_created == original_created
      assert %DateTime{} = updated.meta_last_modified
    end

    test "always updates meta_last_modified" do
      old_modified = ~U[2020-01-01 00:00:00Z]
      resource = %{meta_created: ~U[2024-01-01 00:00:00Z], meta_last_modified: old_modified}
      updated = Metadata.update_metadata(resource)

      assert DateTime.compare(updated.meta_last_modified, old_modified) == :gt
    end

    test "sets meta_resource_type when provided and key exists" do
      resource = %{meta_created: nil, meta_last_modified: nil, meta_resource_type: nil}
      updated = Metadata.update_metadata(resource, "User")

      assert updated.meta_resource_type == "User"
    end

    test "does not add meta_resource_type key if resource lacks it" do
      resource = %{meta_created: nil, meta_last_modified: nil}
      updated = Metadata.update_metadata(resource, "User")

      refute Map.has_key?(updated, :meta_resource_type)
    end
  end
end
