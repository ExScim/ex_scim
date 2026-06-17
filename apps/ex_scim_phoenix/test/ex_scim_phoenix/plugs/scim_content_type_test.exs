defmodule ExScimPhoenix.Plugs.ScimContentTypeTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias ExScimPhoenix.Plugs.ScimContentType

  describe "call/2" do
    test "sets response content-type to application/scim+json" do
      conn =
        conn(:get, "/Users")
        |> ScimContentType.call(ScimContentType.init([]))

      assert get_resp_header(conn, "content-type") == ["application/scim+json; charset=utf-8"]
    end

    test "assigns scim_version 2.0" do
      conn =
        conn(:get, "/Users")
        |> ScimContentType.call(ScimContentType.init([]))

      assert conn.assigns.scim_version == "2.0"
    end

    test "does not halt the connection" do
      conn =
        conn(:get, "/Users")
        |> ScimContentType.call(ScimContentType.init([]))

      refute conn.halted
    end
  end

  describe "init/1" do
    test "returns opts unchanged" do
      assert ScimContentType.init([]) == []
      assert ScimContentType.init(:default) == :default
    end
  end
end
