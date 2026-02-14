defmodule ExScimPhoenix.Plugs.RequireScopes do
  @moduledoc """
  Ensures SCIM scope has required authorization scopes.
  """

  import Plug.Conn
  alias ExScim.Scope

  def init(opts) do
    scopes = opts |> Keyword.get(:scopes, []) |> List.wrap()
    %{scopes: scopes}
  end

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
