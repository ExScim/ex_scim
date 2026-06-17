defmodule ExScimClient.Resources.UsersTest do
  use ExUnit.Case, async: false

  alias ExScimClient.Client
  alias ExScimClient.Resources.Users

  @stub ExScimClient.Stub

  setup do
    client = Client.new("https://example.com/scim/v2", "token123")
    {:ok, client: client}
  end

  describe "create/2" do
    test "sends POST /Users with a JSON body and bearer auth", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/scim/v2/Users"
        assert ["Bearer token123"] = Plug.Conn.get_req_header(conn, "authorization")
        assert %{"userName" => "jdoe"} = body_params(conn)

        Req.Test.json(conn, %{"id" => "u1", "userName" => "jdoe"})
      end)

      assert {:ok, %{"id" => "u1", "userName" => "jdoe"}} =
               Users.create(client, %{"userName" => "jdoe"})
    end
  end

  describe "get/3" do
    test "sends GET /Users/:id", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/scim/v2/Users/u1"
        Req.Test.json(conn, %{"id" => "u1"})
      end)

      assert {:ok, %{"id" => "u1"}} = Users.get(client, "u1")
    end

    test "passes attributes and excludedAttributes as query params", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        q = URI.decode_query(conn.query_string)
        assert q["attributes"] == "userName,emails"
        assert q["excludedAttributes"] == "groups"
        Req.Test.json(conn, %{"id" => "u1"})
      end)

      assert {:ok, _} =
               Users.get(client, "u1",
                 attributes: ["userName", "emails"],
                 excluded_attributes: ["groups"]
               )
    end
  end

  describe "list/2" do
    test "sends GET /Users", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/scim/v2/Users"
        Req.Test.json(conn, %{"totalResults" => 0, "Resources" => []})
      end)

      assert {:ok, %{"totalResults" => 0}} = Users.list(client)
    end

    test "includes a filter query param", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        q = URI.decode_query(conn.query_string)
        assert q["filter"] == ~s(userName eq "jdoe")
        Req.Test.json(conn, %{"Resources" => []})
      end)

      assert {:ok, _} = Users.list(client, filter: ~s(userName eq "jdoe"))
    end
  end

  describe "update/3" do
    test "sends PUT /Users/:id with a body", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/scim/v2/Users/u1"
        assert %{"displayName" => "New"} = body_params(conn)
        Req.Test.json(conn, %{"id" => "u1", "displayName" => "New"})
      end)

      assert {:ok, %{"displayName" => "New"}} =
               Users.update(client, "u1", %{"displayName" => "New"})
    end
  end

  describe "patch/3" do
    test "sends PATCH /Users/:id with a PatchOp body", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/scim/v2/Users/u1"
        body = body_params(conn)
        assert "urn:ietf:params:scim:api:messages:2.0:PatchOp" in body["schemas"]
        assert [%{"op" => "replace"}] = body["Operations"]
        Req.Test.json(conn, %{"id" => "u1"})
      end)

      assert {:ok, _} =
               Users.patch(client, "u1", [
                 %{"op" => "replace", "path" => "displayName", "value" => "X"}
               ])
    end
  end

  describe "delete/2" do
    test "sends DELETE /Users/:id", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/scim/v2/Users/u1"
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok, _} = Users.delete(client, "u1")
    end
  end

  describe "error responses" do
    test "non-2xx returns {:error, %{status, body}}", %{client: client} do
      Req.Test.stub(@stub, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"detail" => "User u1 not found", "status" => "404"})
      end)

      assert {:error, %{status: 404, body: %{"detail" => "User u1 not found"}}} =
               Users.get(client, "u1")
    end
  end

  defp body_params(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end
end
