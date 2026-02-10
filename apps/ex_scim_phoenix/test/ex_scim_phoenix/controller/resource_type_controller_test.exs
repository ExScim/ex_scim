defmodule ExScimPhoenix.Controller.ResourceTypeControllerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  import ExScimPhoenix.Test.ConnHelpers

  alias ExScimPhoenix.Controller.ResourceTypeController

  describe "index/2" do
    test "returns list of resource types with correct SCIM ListResponse format" do
      conn = conn(:get, "/ResourceTypes")
      conn = ResourceTypeController.index(conn, %{})

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/scim+json; charset=utf-8"]

      response = decode_response(conn)

      # Verify SCIM ListResponse schema
      assert response["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:ListResponse"]
      assert response["totalResults"] == 2
      assert response["startIndex"] == 1
      assert response["itemsPerPage"] == 2
      assert is_list(response["Resources"])
      assert length(response["Resources"]) == 2
    end

    test "returns User and Group resource types" do
      conn = conn(:get, "/ResourceTypes")
      conn = ResourceTypeController.index(conn, %{})

      response = decode_response(conn)
      resource_types = response["Resources"]

      user_rt = Enum.find(resource_types, fn rt -> rt["id"] == "User" end)
      group_rt = Enum.find(resource_types, fn rt -> rt["id"] == "Group" end)

      refute is_nil(user_rt)
      refute is_nil(group_rt)
    end

    test "User resource type has correct attributes" do
      conn = conn(:get, "/ResourceTypes")
      conn = ResourceTypeController.index(conn, %{})

      response = decode_response(conn)
      user_rt = Enum.find(response["Resources"], fn rt -> rt["id"] == "User" end)

      # Verify required RFC 7643 attributes
      assert user_rt["schemas"] == ["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]
      assert user_rt["id"] == "User"
      assert user_rt["name"] == "User"
      assert user_rt["endpoint"] == "/Users"
      assert user_rt["description"] == "User Account"
      assert user_rt["schema"] == "urn:ietf:params:scim:schemas:core:2.0:User"

      # Verify schemaExtensions
      assert is_list(user_rt["schemaExtensions"])
      assert length(user_rt["schemaExtensions"]) == 1

      enterprise_ext = List.first(user_rt["schemaExtensions"])
      assert enterprise_ext["schema"] == "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
      assert enterprise_ext["required"] == false

      # Verify meta object
      assert is_map(user_rt["meta"])
      assert user_rt["meta"]["resourceType"] == "ResourceType"
      assert String.contains?(user_rt["meta"]["location"], "/scim/v2/ResourceTypes/User")
    end

    test "Group resource type has correct attributes" do
      conn = conn(:get, "/ResourceTypes")
      conn = ResourceTypeController.index(conn, %{})

      response = decode_response(conn)
      group_rt = Enum.find(response["Resources"], fn rt -> rt["id"] == "Group" end)

      # Verify required RFC 7643 attributes
      assert group_rt["schemas"] == ["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]
      assert group_rt["id"] == "Group"
      assert group_rt["name"] == "Group"
      assert group_rt["endpoint"] == "/Groups"
      assert group_rt["description"] == "Group Account"
      assert group_rt["schema"] == "urn:ietf:params:scim:schemas:core:2.0:Group"

      # Verify meta object
      assert is_map(group_rt["meta"])
      assert group_rt["meta"]["resourceType"] == "ResourceType"
      assert String.contains?(group_rt["meta"]["location"], "/scim/v2/ResourceTypes/Group")
    end
  end

  describe "show/2" do
    test "returns specific User resource type" do
      conn = conn(:get, "/ResourceTypes/User")
      conn = ResourceTypeController.show(conn, %{"id" => "User"})

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/scim+json; charset=utf-8"]

      response = decode_response(conn)

      assert response["schemas"] == ["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]
      assert response["id"] == "User"
      assert response["name"] == "User"
      assert response["endpoint"] == "/Users"
      assert response["schema"] == "urn:ietf:params:scim:schemas:core:2.0:User"
    end

    test "returns specific Group resource type" do
      conn = conn(:get, "/ResourceTypes/Group")
      conn = ResourceTypeController.show(conn, %{"id" => "Group"})

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/scim+json; charset=utf-8"]

      response = decode_response(conn)

      assert response["schemas"] == ["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]
      assert response["id"] == "Group"
      assert response["name"] == "Group"
      assert response["endpoint"] == "/Groups"
      assert response["schema"] == "urn:ietf:params:scim:schemas:core:2.0:Group"
    end

    test "returns 404 for non-existent resource type" do
      conn = conn(:get, "/ResourceTypes/NonExistent")
      conn = ResourceTypeController.show(conn, %{"id" => "NonExistent"})

      assert conn.status == 404
      assert get_resp_header(conn, "content-type") == ["application/scim+json; charset=utf-8"]

      response = decode_response(conn)

      assert response["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:Error"]
      assert response["detail"] == "Resource NonExistent not found"
      assert response["status"] == "404"
    end

    test "handles case-sensitive resource type IDs" do
      # Test lowercase - should not match
      conn = conn(:get, "/ResourceTypes/user")
      conn = ResourceTypeController.show(conn, %{"id" => "user"})

      assert conn.status == 404

      # Test correct case - should match
      conn = conn(:get, "/ResourceTypes/User")
      conn = ResourceTypeController.show(conn, %{"id" => "User"})

      assert conn.status == 200
    end
  end

  describe "configuration integration" do
    test "uses base_url from ExScim.Config in meta.location" do
      original_base_url = Application.get_env(:ex_scim, :base_url, "http://localhost:4000")

      try do
        Application.put_env(:ex_scim, :base_url, "https://example.com")

        conn = conn(:get, "/ResourceTypes/User")
        conn = ResourceTypeController.show(conn, %{"id" => "User"})

        response = decode_response(conn)
        assert response["meta"]["location"] == "https://example.com/scim/v2/ResourceTypes/User"
      after
        if original_base_url do
          Application.put_env(:ex_scim, :base_url, original_base_url)
        else
          Application.delete_env(:ex_scim, :base_url)
        end
      end
    end
  end

  describe "resource_types config" do
    test "empty resource_types config returns empty ListResponse" do
      original = Application.get_env(:ex_scim, :resource_types)

      try do
        Application.put_env(:ex_scim, :resource_types, [])

        conn = conn(:get, "/ResourceTypes")
        conn = ResourceTypeController.index(conn, %{})

        response = decode_response(conn)
        assert response["totalResults"] == 0
        assert response["Resources"] == []
      after
        restore_resource_types(original)
      end
    end

    test "custom resource type appears in response" do
      original = Application.get_env(:ex_scim, :resource_types)

      try do
        Application.put_env(:ex_scim, :resource_types, [
          %{
            id: "Device",
            name: "Device",
            endpoint: "/Devices",
            description: "Device Resource",
            schema: "urn:example:schemas:2.0:Device",
            schema_extensions: []
          }
        ])

        conn = conn(:get, "/ResourceTypes")
        conn = ResourceTypeController.index(conn, %{})

        response = decode_response(conn)
        assert response["totalResults"] == 1

        device_rt = List.first(response["Resources"])
        assert device_rt["id"] == "Device"
        assert device_rt["name"] == "Device"
        assert device_rt["endpoint"] == "/Devices"
        assert device_rt["description"] == "Device Resource"
        assert device_rt["schema"] == "urn:example:schemas:2.0:Device"
        refute Map.has_key?(device_rt, "schemaExtensions")
      after
        restore_resource_types(original)
      end
    end

    test "custom resource type with extensions includes schemaExtensions" do
      original = Application.get_env(:ex_scim, :resource_types)

      try do
        Application.put_env(:ex_scim, :resource_types, [
          %{
            id: "Device",
            name: "Device",
            endpoint: "/Devices",
            description: "Device Resource",
            schema: "urn:example:schemas:2.0:Device",
            schema_extensions: [
              %{schema: "urn:example:schemas:extension:2.0:Device", required: true}
            ]
          }
        ])

        conn = conn(:get, "/ResourceTypes/Device")
        conn = ResourceTypeController.show(conn, %{"id" => "Device"})

        assert conn.status == 200
        response = decode_response(conn)
        assert length(response["schemaExtensions"]) == 1

        ext = List.first(response["schemaExtensions"])
        assert ext["schema"] == "urn:example:schemas:extension:2.0:Device"
        assert ext["required"] == true
      after
        restore_resource_types(original)
      end
    end

    test "removing Group from config excludes it from response" do
      original = Application.get_env(:ex_scim, :resource_types)

      try do
        Application.put_env(:ex_scim, :resource_types, [
          %{
            id: "User",
            name: "User",
            endpoint: "/Users",
            description: "User Account",
            schema: "urn:ietf:params:scim:schemas:core:2.0:User",
            schema_extensions: []
          }
        ])

        conn = conn(:get, "/ResourceTypes")
        conn = ResourceTypeController.index(conn, %{})

        response = decode_response(conn)
        assert response["totalResults"] == 1

        ids = Enum.map(response["Resources"], fn rt -> rt["id"] end)
        assert "User" in ids
        refute "Group" in ids
      after
        restore_resource_types(original)
      end
    end
  end

  defp restore_resource_types(nil), do: Application.delete_env(:ex_scim, :resource_types)
  defp restore_resource_types(value), do: Application.put_env(:ex_scim, :resource_types, value)
end
