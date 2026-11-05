defmodule ExScim.Groups.Mapper.DefaultMapperTest do
  use ExUnit.Case, async: true

  alias ExScim.Groups.Mapper.DefaultMapper

  @group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"

  describe "from_scim/2" do
    test "keeps the SCIM attributes and drops server-assigned ones" do
      scim = %{
        "id" => "g1",
        "externalId" => "ext-1",
        "displayName" => "Engineering",
        "members" => [%{"value" => "u1", "display" => "Alice"}],
        "schemas" => [@group_schema],
        "meta" => %{"created" => "2024-01-01T00:00:00Z"}
      }

      assert {:ok, domain} = DefaultMapper.from_scim(scim, nil)

      assert domain == %{
               "externalId" => "ext-1",
               "displayName" => "Engineering",
               "members" => [%{"value" => "u1", "display" => "Alice"}],
               "schemas" => [@group_schema]
             }
    end
  end

  describe "to_scim/3" do
    test "returns the SCIM attributes with id and meta" do
      domain = %{
        "id" => "g1",
        "externalId" => "ext-1",
        "displayName" => "Engineering",
        "members" => [%{"value" => "u1"}],
        "schemas" => [@group_schema],
        meta_created: ~U[2024-01-01 00:00:00Z],
        meta_last_modified: ~U[2024-01-02 00:00:00Z]
      }

      assert {:ok, scim} = DefaultMapper.to_scim(domain, nil)
      assert scim["id"] == "g1"
      assert scim["externalId"] == "ext-1"
      assert scim["displayName"] == "Engineering"
      assert scim["members"] == [%{"value" => "u1"}]
      assert scim["schemas"] == [@group_schema]
      assert scim["meta"]["created"] == "2024-01-01T00:00:00Z"
      assert scim["meta"]["lastModified"] == "2024-01-02T00:00:00Z"
      assert scim["meta"]["resourceType"] == "Group"
      assert scim["meta"]["version"] =~ ~r/^W\//
      refute Map.has_key?(scim, :meta_created)
    end

    test "defaults schemas and strips nil values" do
      assert {:ok, scim} =
               DefaultMapper.to_scim(%{"displayName" => "Eng", "externalId" => nil}, nil)

      assert scim["displayName"] == "Eng"
      assert scim["schemas"] == [@group_schema]
      refute Map.has_key?(scim, "id")
      refute Map.has_key?(scim, "externalId")
      assert scim["meta"]["resourceType"] == "Group"
    end

    test "includes meta.location when a :location opt is given" do
      assert {:ok, scim} =
               DefaultMapper.to_scim(%{"displayName" => "Eng"}, nil,
                 location: "https://example.com/scim/v2/Groups/g1"
               )

      assert scim["meta"]["location"] == "https://example.com/scim/v2/Groups/g1"
    end
  end

  describe "meta callbacks (from the Adapter)" do
    test "get_meta_created/1 and get_meta_last_modified/1 read the struct fields" do
      group = %{
        meta_created: ~U[2024-01-01 00:00:00Z],
        meta_last_modified: ~U[2024-01-02 00:00:00Z]
      }

      assert DefaultMapper.get_meta_created(group) == ~U[2024-01-01 00:00:00Z]
      assert DefaultMapper.get_meta_last_modified(group) == ~U[2024-01-02 00:00:00Z]
    end

    test "get_meta_version/1 computes a weak ETag from last_modified" do
      version = DefaultMapper.get_meta_version(%{meta_last_modified: ~U[2024-01-02 00:00:00Z]})
      assert version =~ ~r/^W\/"/
    end

    test "get_meta_version/1 returns nil with no version source" do
      assert DefaultMapper.get_meta_version(%{meta_last_modified: nil}) == nil
    end

    test "format_meta/2 builds a meta map with resourceType Group" do
      meta = DefaultMapper.format_meta(%{meta_last_modified: ~U[2024-01-02 00:00:00Z]}, [])

      assert meta["resourceType"] == "Group"
      assert meta["lastModified"] == "2024-01-02T00:00:00Z"
    end

    test "format_datetime/1 and parse_datetime/1 delegate to Metadata" do
      assert DefaultMapper.format_datetime(~U[2024-01-01 00:00:00Z]) == "2024-01-01T00:00:00Z"
      assert %DateTime{} = DefaultMapper.parse_datetime("2024-01-01T00:00:00Z")
      assert DefaultMapper.parse_datetime(nil) == nil
    end
  end

  describe "roundtrip" do
    test "from_scim |> to_scim preserves displayName, members, and schemas" do
      scim = %{
        "displayName" => "Engineering",
        "members" => [%{"value" => "u1"}],
        "schemas" => [@group_schema]
      }

      assert {:ok, domain} = DefaultMapper.from_scim(scim, nil)
      assert {:ok, back} = DefaultMapper.to_scim(domain, nil)

      assert back["displayName"] == "Engineering"
      assert back["members"] == [%{"value" => "u1"}]
      assert back["schemas"] == [@group_schema]
    end
  end
end
