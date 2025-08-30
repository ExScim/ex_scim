defmodule ExScim do
  @moduledoc """
  Core SCIM library providing storage adapters, operations, and configuration.
  
  ## Configuration
  
  Configure adapters in your application config:
  
      config :ex_scim,
        storage_strategy: MyApp.Storage,
        id_generator: MyApp.IdGenerator,
        auth_provider: MyApp.AuthProvider
  
  ## Examples
  
      iex> ExScim.version() |> is_binary()
      true
  """

  @doc """
  Returns the application version.
  
  ## Examples
  
      iex> version = ExScim.version()
      iex> String.contains?(version, ".")
      true
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:ex_scim, :vsn) |> to_string()
  end
end
