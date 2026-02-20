defmodule ExScimPhoenix.ErrorResponse do
  @moduledoc """
  SCIM error response functions for Phoenix controllers.

  This module bridges core SCIM error logic from ExScim.Error with Phoenix HTTP responses,
  providing functions that controllers can import to send RFC 7644 compliant error responses.
  """

  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Sends a SCIM-compliant error response using core ExScim.Error logic.

  * `status` - can be an atom (`:bad_request`) or integer (400)
  * `scim_type` - SCIM error type atom from ExScim.Error.scim_type()
  * `detail` - human-readable error description
  """
  @spec send_scim_error(Plug.Conn.t(), atom() | integer(), atom(), String.t()) :: Plug.Conn.t()
  def send_scim_error(conn, status, scim_type, detail) do
    status_code = Plug.Conn.Status.code(status)
    error_response = ExScim.Error.build_error_response(status_code, scim_type, detail)

    conn
    |> put_status(status_code)
    |> json(error_response)
    |> halt()
  end

  @doc """
  Sends a SCIM validation error list response using core ExScim.Error logic.

  Each error must be a map with:
    * `"path"` - the SCIM attribute path
    * `"message"` - the error message
  """
  @spec send_validation_errors(Plug.Conn.t(), [map()]) :: Plug.Conn.t()
  def send_validation_errors(conn, errors) do
    error_response = ExScim.Error.build_validation_error_response(errors)

    conn
    |> put_status(400)
    |> json(error_response)
    |> halt()
  end

  @doc """
  Sends a SCIM error response based on HTTP status code using core ExScim.Error logic.
  """
  @spec send_scim_error_from_status(Plug.Conn.t(), atom() | integer()) :: Plug.Conn.t()
  def send_scim_error_from_status(conn, status) do
    status_code = Plug.Conn.Status.code(status)
    error_response = ExScim.Error.build_error_from_status(status_code)

    conn
    |> put_status(status_code)
    |> json(error_response)
    |> halt()
  end
end
