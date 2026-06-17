defmodule ExScimClient.Resources.GroupsTest do
  use ExUnit.Case, async: false

  alias ExScimClient.Client
  alias ExScimClient.Resources.Groups

  @stub ExScimClient.Stub

  setup do
    {:ok, client: Client.new("https://example.com/scim/v2", "token123")}
  end

  test "create/2 sends POST /Groups with a JSON body", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/scim/v2/Groups"
      assert %{"displayName" => "Eng"} = body_params(conn)
      Req.Test.json(conn, %{"id" => "g1", "displayName" => "Eng"})
    end)

    assert {:ok, %{"id" => "g1"}} = Groups.create(client, %{"displayName" => "Eng"})
  end

  test "get/3 sends GET /Groups/:id", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/scim/v2/Groups/g1"
      Req.Test.json(conn, %{"id" => "g1"})
    end)

    assert {:ok, %{"id" => "g1"}} = Groups.get(client, "g1")
  end

  test "list/2 sends GET /Groups and forwards a filter", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.request_path == "/scim/v2/Groups"
      assert URI.decode_query(conn.query_string)["filter"] == ~s(displayName eq "Eng")
      Req.Test.json(conn, %{"Resources" => []})
    end)

    assert {:ok, _} = Groups.list(client, filter: ~s(displayName eq "Eng"))
  end

  test "update/3 sends PUT /Groups/:id", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/scim/v2/Groups/g1"
      assert %{"displayName" => "New"} = body_params(conn)
      Req.Test.json(conn, %{"id" => "g1"})
    end)

    assert {:ok, _} = Groups.update(client, "g1", %{"displayName" => "New"})
  end

  test "patch/3 sends PATCH /Groups/:id with a PatchOp body", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "PATCH"
      body = body_params(conn)
      assert "urn:ietf:params:scim:api:messages:2.0:PatchOp" in body["schemas"]
      Req.Test.json(conn, %{"id" => "g1"})
    end)

    assert {:ok, _} =
             Groups.patch(client, "g1", [%{"op" => "add", "path" => "members", "value" => %{}}])
  end

  test "delete/2 sends DELETE /Groups/:id", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/scim/v2/Groups/g1"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, _} = Groups.delete(client, "g1")
  end

  defp body_params(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end
end
