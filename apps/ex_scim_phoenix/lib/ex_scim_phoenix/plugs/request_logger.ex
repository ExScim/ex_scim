defmodule ExScimPhoenix.Plugs.RequestLogger do
  @moduledoc """
  Logs incoming SCIM requests and response times for debugging.

  Logs the HTTP method and path at `:info` level, headers and params at
  `:debug` level, and response status with duration on completion.
  """

  require Logger

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    start_time = System.monotonic_time()

    # Log request details
    Logger.info("REQUEST: #{conn.method} #{conn.request_path}")
    Logger.debug("Headers: #{inspect(conn.req_headers)}")
    Logger.debug("Params: #{inspect(conn.params)}")

    conn
    |> Plug.Conn.register_before_send(fn conn ->
      duration = System.monotonic_time() - start_time

      Logger.info(
        "RESPONSE: #{conn.status} in #{System.convert_time_unit(duration, :native, :microsecond)}μs"
      )

      Logger.debug("Response headers: #{inspect(conn.resp_headers)}")
      conn
    end)
  end
end
