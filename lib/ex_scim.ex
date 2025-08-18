defmodule ExScim do
  @moduledoc """
  SCIM v2.0 implementation for identity management.
  """

  @doc """
  Convenience function to get application version.
  """
  def version do
    Application.spec(:ex_scim, :vsn) |> to_string()
  end
end
