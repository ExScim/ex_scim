defmodule ExScimClient.MeTest do
  use ExUnit.Case, async: false

  alias ExScimClient.Client
  alias ExScimClient.Me

  @stub ExScimClient.Stub

  setup do
    {:ok, client: Client.new("https://example.com/scim/v2", "token123")}
  end

  test "get/2 sends GET /Me", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/scim/v2/Me"
      Req.Test.json(conn, %{"id" => "me"})
    end)

    assert {:ok, %{"id" => "me"}} = Me.get(client)
  end

  test "get/2 forwards attributes as query params", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert URI.decode_query(conn.query_string)["attributes"] == "userName,displayName"
      Req.Test.json(conn, %{"id" => "me"})
    end)

    assert {:ok, _} = Me.get(client, attributes: ["userName", "displayName"])
  end

  test "update/2 sends PUT /Me with a body", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/scim/v2/Me"
      assert %{"displayName" => "Updated"} = body_params(conn)
      Req.Test.json(conn, %{"id" => "me", "displayName" => "Updated"})
    end)

    assert {:ok, _} = Me.update(client, %{"displayName" => "Updated"})
  end

  test "patch/2 sends PATCH /Me with a PatchOp body", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/scim/v2/Me"
      body = body_params(conn)
      assert "urn:ietf:params:scim:api:messages:2.0:PatchOp" in body["schemas"]
      Req.Test.json(conn, %{"id" => "me"})
    end)

    assert {:ok, _} =
             Me.patch(client, [%{"op" => "replace", "path" => "displayName", "value" => "N"}])
  end

  defp body_params(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end
end
