defmodule ExScimClient.Resources.BulkTest do
  use ExUnit.Case, async: false

  alias ExScimClient.Client
  alias ExScimClient.Resources.Bulk

  @stub ExScimClient.Stub

  setup do
    {:ok, client: Client.new("https://example.com/scim/v2", "token123")}
  end

  test "execute/2 sends POST /Bulk with the operations body", %{client: client} do
    operations = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
      "Operations" => [%{"method" => "POST", "path" => "/Users", "data" => %{"userName" => "x"}}]
    }

    Req.Test.stub(@stub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/scim/v2/Bulk"
      body = body_params(conn)
      assert [%{"method" => "POST"}] = body["Operations"]
      Req.Test.json(conn, %{"Operations" => [%{"status" => "201"}]})
    end)

    assert {:ok, %{"Operations" => [%{"status" => "201"}]}} = Bulk.execute(client, operations)
  end

  test "execute/2 surfaces a non-2xx error", %{client: client} do
    Req.Test.stub(@stub, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"detail" => "bad bulk", "status" => "400"})
    end)

    assert {:error, %{status: 400, body: %{"detail" => "bad bulk"}}} =
             Bulk.execute(client, %{"Operations" => []})
  end

  defp body_params(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end
end
