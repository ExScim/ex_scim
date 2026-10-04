defmodule ExScimPhoenix.Plugs.Authorize do
  @moduledoc """
  Authorizes the request against the configured `ExScim.Authorization` policy.
  """

  import Plug.Conn
  alias ExScim.Authorization
  alias ExScim.Scope

  @doc false
  def init(opts) do
    %{resource: Keyword.fetch!(opts, :resource), action: Keyword.fetch!(opts, :action)}
  end

  @doc false
  def call(conn, %{resource: resource, action: action}) do
    authorize(conn, resource, action)
  end

  @doc """
  Authorizes `conn` for `action` on `resource`, halting it when access is denied.

  For controllers that only know the resource at request time.
  """
  @spec authorize(
          Plug.Conn.t(),
          ExScim.Authorization.Adapter.resource(),
          ExScim.Authorization.Adapter.action()
        ) ::
          Plug.Conn.t()
  def authorize(conn, resource, action) do
    case conn.assigns[:scim_scope] do
      %Scope{} = scope ->
        case Authorization.authorize(scope, resource, action) do
          :ok ->
            conn

          {:error, denial} ->
            conn
            |> ExScimPhoenix.ErrorResponse.send_scim_error(
              :forbidden,
              :insufficient_scope,
              Authorization.denial_detail(denial)
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
