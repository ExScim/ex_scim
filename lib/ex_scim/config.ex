defmodule ExScim.Config do
  @moduledoc """
  Centralized configuration utilities for the ExScim library.

  This module provides a unified interface for accessing ExScim configuration
  values with consistent defaults and proper environment variable support.
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
end
