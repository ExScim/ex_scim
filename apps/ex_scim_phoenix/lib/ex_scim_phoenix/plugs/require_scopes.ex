defmodule ExScimPhoenix.Plugs.RequireScopes do
  @moduledoc """
  Ensures the authenticated SCIM scope has the required authorization scopes.

  Reads the `:scopes` option (a list of scope strings). If any required scope
  is missing from `conn.assigns.scim_scope`, the request is halted with a 403.
  """

  import Plug.Conn
  alias ExScim.Scope

  @doc false
  def init(opts) do
    scopes = opts |> Keyword.get(:scopes, []) |> List.wrap()
    %{scopes: scopes}
  end

  @doc false
  def call(conn, %{scopes: required_scopes}) do
    case conn.assigns[:scim_scope] do
      %Scope{scopes: scopes} ->
        if Enum.all?(required_scopes, &(&1 in scopes)) do
          conn
        else
          conn
          |> ExScimPhoenix.ErrorResponse.send_scim_error(
            :forbidden,
            :insufficient_scope,
            "Missing required scope(s): #{Enum.join(required_scopes, ", ")}"
          )
          |> halt()
        end

      _ ->
        conn
        |> ExScimPhoenix.ErrorResponse.send_scim_error(
          :unauthorized,
          :no_authn,
          "Authentication required"
        )
        |> halt()
    end
  end
end
