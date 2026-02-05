defmodule ExScim.Config do
  @moduledoc """
  Centralized configuration management for ExScim.
  """

  @doc """
  Returns the configured base URL for SCIM endpoints.

  The base URL is used for generating location headers, documentation URIs,
  and other absolute URLs in SCIM responses.

  Configuration sources (in order of precedence):
  1. Application environment: `:ex_scim, :base_url`
  2. System environment variable: `SCIM_BASE_URL`
  3. Default fallback: "http://localhost:4000"

  ## Examples

      iex> ExScim.Config.base_url()
      "http://localhost:4000"
      
      # With configuration
      Application.put_env(:ex_scim, :base_url, "https://api.example.com")
      iex> ExScim.Config.base_url()
      "https://api.example.com"
  """
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:ex_scim, :base_url) ||
      System.get_env("SCIM_BASE_URL") ||
      "http://localhost:4000"
  end

  @doc """
  Returns the configured base URL with the SCIM v2 API path appended.

  This is a convenience function for generating SCIM v2 endpoint URLs.

  ## Examples

      iex> ExScim.Config.scim_base_url()
      "http://localhost:4000/scim/v2"
  """
  @spec scim_base_url() :: String.t()
  def scim_base_url do
    "#{base_url()}/scim/v2"
  end

  @doc """
  Generates a full SCIM resource URL for the given resource type and ID.

  ## Examples

      iex> ExScim.Config.resource_url("Users", "123")
      "http://localhost:4000/scim/v2/Users/123"
      
      iex> ExScim.Config.resource_url("Groups", "456")
      "http://localhost:4000/scim/v2/Groups/456"
  """
  @spec resource_url(String.t(), String.t()) :: String.t()
  def resource_url(resource_type, resource_id)
      when is_binary(resource_type) and is_binary(resource_id) do
    "#{scim_base_url()}/#{resource_type}/#{resource_id}"
  end

  @doc """
  Generates a SCIM resource collection URL for the given resource type.

  ## Examples

      iex> ExScim.Config.collection_url("Users")
      "http://localhost:4000/scim/v2/Users"
  """
  @spec collection_url(String.t()) :: String.t()
  def collection_url(resource_type) when is_binary(resource_type) do
    "#{scim_base_url()}/#{resource_type}"
  end

  @doc """
  Returns whether SCIM PATCH operations are supported.
  """
  @spec patch_supported() :: boolean()
  def patch_supported do
    Application.get_env(:ex_scim, :patch_supported, false)
  end

  @doc """
  Returns whether SCIM bulk operations are supported.
  """
  @spec bulk_supported() :: boolean()
  def bulk_supported do
    Application.get_env(:ex_scim, :bulk_supported, true)
  end

  @doc """
  Returns the maximum number of operations per bulk request.
  """
  @spec bulk_max_operations() :: integer()
  def bulk_max_operations do
    Application.get_env(:ex_scim, :bulk_max_operations, 1000)
  end

  @doc """
  Returns the maximum payload size in bytes for bulk operations.
  """
  @spec bulk_max_payload_size() :: integer()
  def bulk_max_payload_size do
    Application.get_env(:ex_scim, :bulk_max_payload_size, 1_048_576)
  end

  @doc """
  Returns whether SCIM filter operations are supported.
  """
  @spec filter_supported() :: boolean()
  def filter_supported do
    Application.get_env(:ex_scim, :filter_supported, false)
  end

  @doc """
  Returns the maximum number of results for filter queries.
  """
  @spec filter_max_results() :: integer()
  def filter_max_results do
    Application.get_env(:ex_scim, :filter_max_results, 200)
  end

  @doc """
  Returns whether SCIM change password operations are supported.
  """
  @spec change_password_supported() :: boolean()
  def change_password_supported do
    Application.get_env(:ex_scim, :change_password_supported, false)
  end

  @doc """
  Returns whether SCIM sort operations are supported.
  """
  @spec sort_supported() :: boolean()
  def sort_supported do
    Application.get_env(:ex_scim, :sort_supported, false)
  end

  @doc """
  Returns whether SCIM ETag support is enabled.
  """
  @spec etag_supported() :: boolean()
  def etag_supported do
    Application.get_env(:ex_scim, :etag_supported, false)
  end

  @doc """
  Returns the documentation URI for the SCIM service provider, or nil if not configured.
  """
  @spec documentation_uri() :: String.t() | nil
  def documentation_uri do
    Application.get_env(:ex_scim, :documentation_uri, nil)
  end

  @doc """
  Returns the list of authentication schemes supported by the SCIM service provider.

  Each scheme is a map with string keys matching RFC 7643 (`type`, `name`, `description`,
  and optionally `specUri`, `documentationUri`, `primary`).
  """
  @spec authentication_schemes() :: [map()]
  def authentication_schemes do
    Application.get_env(:ex_scim, :authentication_schemes, [])
  end

  @doc """
  Returns the list of schema modules to use for SCIM schema definitions.

  Each module must implement the Schema Builder DSL and provide `schema_id/0`
  and `to_map/0` functions.

  ## Configuration

      config :ex_scim, :schema_modules, [
        MyApp.Schemas.User,
        MyApp.Schemas.Group
      ]

  ## Default

  When not configured, defaults to the built-in schema definitions:

  - `ExScim.Schema.Definitions.User`
  - `ExScim.Schema.Definitions.EnterpriseUser`
  - `ExScim.Schema.Definitions.Group`
  """
  @spec schema_modules() :: [module()]
  def schema_modules do
    Application.get_env(:ex_scim, :schema_modules, [
      ExScim.Schema.Definitions.User,
      ExScim.Schema.Definitions.EnterpriseUser,
      ExScim.Schema.Definitions.Group
    ])
  end
end
