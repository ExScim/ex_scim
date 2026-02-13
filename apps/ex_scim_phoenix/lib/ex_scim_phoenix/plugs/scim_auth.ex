defmodule ExScimPhoenix.Plugs.ScimAuth do
  @moduledoc """
  SCIM authentication plug supporting Bearer tokens and Basic Auth.
  """

  import Plug.Conn
  import Phoenix.Controller
  alias ExScim.Scope
  alias ExScim.Auth.AuthProvider

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        handle_auth_result(conn, AuthProvider.validate_bearer(token))

      ["Basic " <> encoded] ->
        with {:ok, {u, p}} <- decode_basic(encoded),
             result <- AuthProvider.validate_basic(u, p) do
          handle_auth_result(conn, result)
        else
          {:error, reason} -> send_scim_error(conn, reason)
        end

      [] ->
        send_scim_error(conn, :missing_auth)

      _ ->
        send_scim_error(conn, :unsupported_scheme)
    end
  end

  defp handle_auth_result(conn, {:ok, %Scope{} = scope}) do
    assign(conn, :scim_scope, scope)
  end

  defp handle_auth_result(conn, {:error, reason}) do
    send_scim_error(conn, reason)
  end

  defp decode_basic(encoded) do
    with {:ok, decoded} <- Base.decode64(encoded),
         [username, password] <- String.split(decoded, ":", parts: 2) do
      {:ok, {username, password}}
    else
      _ -> {:error, :invalid_basic_format}
    end
  end

  defp send_scim_error(conn, reason) do
    {status, detail} = scim_error_details(reason)

    error_response = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "status" => to_string(status),
      "scimType" => "invalidCredentials",
      "detail" => detail
    }

    conn
    |> put_resp_header("www-authenticate", "Bearer, Basic")
    |> put_status(status)
    |> json(error_response)
    |> halt()
  end

  defp scim_error_details(:missing_auth), do: {401, "Authentication required"}
  defp scim_error_details(:unsupported_scheme), do: {401, "Unsupported authentication method"}
  defp scim_error_details(:invalid_credentials), do: {401, "Invalid username or password"}
  defp scim_error_details(:token_not_found), do: {401, "Bearer token not found"}
  defp scim_error_details(:expired_token), do: {401, "Bearer token expired"}
  defp scim_error_details(:inactive_token), do: {401, "Bearer token inactive"}
  defp scim_error_details(:invalid_basic_format), do: {401, "Malformed basic auth"}
  defp scim_error_details(_), do: {401, "Authentication failed"}
end
