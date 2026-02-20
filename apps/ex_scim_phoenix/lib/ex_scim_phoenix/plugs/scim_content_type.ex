defmodule ExScimPhoenix.Plugs.ScimContentType do
  @moduledoc """
  Sets the response content type to `application/scim+json` per RFC 7644.

  Also assigns `:scim_version` to `"2.0"` on the connection for downstream use.
  """
  import Plug.Conn

  @doc false
  def init(default), do: default

  @doc false
  def call(conn, _default) do
    conn
    |> put_resp_content_type("application/scim+json", "utf-8")
    |> assign(:scim_version, "2.0")
  end
end
