defmodule ExScim.Schema.Repository do
  @moduledoc """
  Schema repository interface that delegates to configurable adapters.

  This module provides a consistent interface for schema operations while
  allowing different implementations (in-memory, database, external service, etc.).
  """

  @behaviour ExScim.Schema.Repository.Adapter

  @impl true
  def get_schema(schema_uri) do
    adapter().get_schema(schema_uri)
  end

  @impl true
  def list_schemas do
    adapter().list_schemas()
  end

  @impl true
  def has_schema?(schema_uri) do
    adapter().has_schema?(schema_uri)
  end

  @doc """
  Gets the configured schema repository adapter.

  Defaults to the in-memory default repository if not configured.
  """
  def adapter do
    Application.get_env(
      :ex_scim,
      :scim_schema_repository,
      ExScim.Schema.Repository.DefaultRepository
    )
  end
end
