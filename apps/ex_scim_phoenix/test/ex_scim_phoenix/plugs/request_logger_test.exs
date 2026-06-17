defmodule ExScimPhoenix.Plugs.RequestLoggerTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn
  import ExUnit.CaptureLog

  alias ExScimPhoenix.Plugs.RequestLogger

  describe "init/1" do
    test "returns opts unchanged" do
      assert RequestLogger.init([]) == []
      assert RequestLogger.init(foo: 1) == [foo: 1]
    end
  end

  describe "call/2" do
    test "logs the request method and path at info level" do
      log =
        capture_log(fn ->
          conn(:get, "/Users") |> RequestLogger.call([])
        end)

      assert log =~ "REQUEST: GET /Users"
    end

    test "does not halt the connection and returns the conn" do
      conn = conn(:post, "/Groups") |> RequestLogger.call([])

      refute conn.halted
      assert %Plug.Conn{} = conn
    end

    test "logs the response status and duration when the response is sent" do
      log =
        capture_log(fn ->
          conn(:get, "/Users")
          |> RequestLogger.call([])
          |> send_resp(200, "ok")
        end)

      assert log =~ "RESPONSE: 200"
      assert log =~ "μs"
    end

    test "logs headers and params at debug level" do
      log =
        capture_log([level: :debug], fn ->
          conn(:get, "/Users")
          |> RequestLogger.call([])
          |> send_resp(201, "created")
        end)

      assert log =~ "Headers:"
      assert log =~ "Params:"
      assert log =~ "Response headers:"
    end
  end
end
