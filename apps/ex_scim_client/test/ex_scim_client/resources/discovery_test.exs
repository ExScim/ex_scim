defmodule ExScimClient.Resources.DiscoveryTest do
  @moduledoc "Covers the read-only discovery resources: Schemas, ResourceTypes, ServiceProviderConfig."
  use ExUnit.Case, async: false

  alias ExScimClient.Client
  alias ExScimClient.Resources.{Schemas, ResourceTypes, ServiceProviderConfig}

  @stub ExScimClient.Stub
  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"
  @group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"
  @enterprise_schema "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

  setup do
    {:ok, client: Client.new("https://example.com/scim/v2", "token123")}
  end

  describe "Schemas" do
    test "list/2 sends GET /Schemas", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/scim/v2/Schemas"
        Req.Test.json(conn, %{"Resources" => []})
      end)

      assert {:ok, _} = Schemas.list(client)
    end

    test "get/3 sends GET /Schemas/:urn (URL-encoded id)", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        # request_path is percent-encoded; decode before comparing to the raw URN.
        assert URI.decode(conn.request_path) == "/scim/v2/Schemas/#{@user_schema}"
        Req.Test.json(conn, %{"id" => @user_schema})
      end)

      assert {:ok, %{"id" => @user_schema}} = Schemas.get(client, @user_schema)
    end

    test "user_schema/group_schema/enterprise_user_schema target the right URNs", %{
      client: client
    } do
      Req.Test.stub(@stub, fn conn ->
        Req.Test.json(conn, %{"path" => URI.decode(conn.request_path)})
      end)

      assert {:ok, %{"path" => path1}} = Schemas.user_schema(client)
      assert path1 == "/scim/v2/Schemas/#{@user_schema}"

      assert {:ok, %{"path" => path2}} = Schemas.group_schema(client)
      assert path2 == "/scim/v2/Schemas/#{@group_schema}"

      assert {:ok, %{"path" => path3}} = Schemas.enterprise_user_schema(client)
      assert path3 == "/scim/v2/Schemas/#{@enterprise_schema}"
    end
  end

  describe "ResourceTypes" do
    test "list/2 sends GET /ResourceTypes", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == "/scim/v2/ResourceTypes"
        Req.Test.json(conn, %{"Resources" => []})
      end)

      assert {:ok, _} = ResourceTypes.list(client)
    end

    test "get/3 sends GET /ResourceTypes/:name", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == "/scim/v2/ResourceTypes/User"
        Req.Test.json(conn, %{"id" => "User"})
      end)

      assert {:ok, %{"id" => "User"}} = ResourceTypes.get(client, "User")
    end
  end

  describe "ServiceProviderConfig" do
    test "get/1 sends GET /ServiceProviderConfig", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.request_path == "/scim/v2/ServiceProviderConfig"
        Req.Test.json(conn, %{"patch" => %{"supported" => true}})
      end)

      assert {:ok, %{"patch" => %{"supported" => true}}} = ServiceProviderConfig.get(client)
    end
  end
end
