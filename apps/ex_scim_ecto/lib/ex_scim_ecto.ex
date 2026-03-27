defmodule ExScimEcto do
  @moduledoc """
  Ecto integration for ExScim providing database storage adapters.

  This package extends ExScim with Ecto-based storage implementations,
  allowing SCIM resources to be stored in SQL databases.

  ## Usage

  Add to your application's storage configuration:

      config :ex_scim, 
        storage_strategy: ExScimEcto.StorageAdapter

  Configure your Ecto repository and database connection separately.

  ## Examples

      iex> ExScimEcto.version() |> is_binary()
      true
  """

  @doc """
  Returns the application version.

  ## Examples

      iex> version = ExScimEcto.version()
      iex> String.contains?(version, ".")
      true
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:ex_scim_ecto, :vsn) |> to_string()
  end
end
