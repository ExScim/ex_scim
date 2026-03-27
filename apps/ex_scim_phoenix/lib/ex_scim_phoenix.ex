defmodule ExScimPhoenix do
  @moduledoc """
  Phoenix integration for ExScim providing HTTP endpoints and controllers.

  This package provides Phoenix controllers, plugs, and routing helpers
  to expose SCIM 2.0 APIs as HTTP endpoints.

  ## Usage

  Add SCIM routes to your Phoenix router:

      use ExScimPhoenix.Router
      
      scope "/scim/v2" do
        scim_routes()
      end

  Configure authentication and scopes in your endpoint or router.

  ## Examples

      iex> ExScimPhoenix.version() |> is_binary()
      true
  """

  @doc """
  Returns the application version.

  ## Examples

      iex> version = ExScimPhoenix.version()
      iex> String.contains?(version, ".")
      true
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:ex_scim_phoenix, :vsn) |> to_string()
  end
end
