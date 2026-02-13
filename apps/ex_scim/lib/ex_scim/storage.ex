defmodule ExScim.Storage do
  @moduledoc """
  Storage interface for SCIM resources using configurable adapters.

  This module provides a unified interface for storing and retrieving Users and Groups.
  The actual storage implementation is configurable via the `:storage_strategy` config.

  ## Configuration

      config :ex_scim, storage_strategy: MyApp.CustomStorage

  ## Examples

      iex> ExScim.Storage.adapter()
      ExScim.Storage.EtsStorage
  """

  @behaviour ExScim.Storage.Adapter

  @default_storage_adapter ExScim.Storage.EtsStorage

  @doc """
  Retrieves a user by ID.

  ## Examples

      iex> ExScim.Storage.get_user("123")
      {:ok, %{"id" => "123", "userName" => "john"}}

      iex> ExScim.Storage.get_user("nonexistent")
      {:error, :not_found}
  """
  @impl true
  def get_user(user_id, scope \\ nil) do
    adapter().get_user(user_id, scope)
  end

  @impl true
  def list_users(filter_ast, sort_opts, pagination_opts, scope \\ nil) do
    adapter().list_users(filter_ast, sort_opts, pagination_opts, scope)
  end

  @doc """
  Creates a new user with the provided data.

  ## Examples

      iex> user_data = %{"userName" => "john", "displayName" => "John Doe"}
      iex> {:ok, _user} = ExScim.Storage.create_user(user_data)
      iex> true
      true
  """
  @impl true
  def create_user(user_data, scope \\ nil) do
    adapter().create_user(user_data, scope)
  end

  @impl true
  def update_user(user_id, user_data, scope \\ nil) do
    adapter().update_user(user_id, user_data, scope)
  end

  @impl true
  def replace_user(user_id, user_data, scope \\ nil) do
    adapter().replace_user(user_id, user_data, scope)
  end

  @impl true
  def delete_user(user_id, scope \\ nil) do
    adapter().delete_user(user_id, scope)
  end

  @impl true
  def user_exists?(user_id, scope \\ nil) do
    adapter().user_exists?(user_id, scope)
  end

  # Group operations
  @impl true
  def get_group(group_id, scope \\ nil) do
    adapter().get_group(group_id, scope)
  end

  @impl true
  def list_groups(filter_ast, sort_opts, pagination_opts, scope \\ nil) do
    adapter().list_groups(filter_ast, sort_opts, pagination_opts, scope)
  end

  @impl true
  def create_group(group_data, scope \\ nil) do
    adapter().create_group(group_data, scope)
  end

  @impl true
  def update_group(group_id, group_data, scope \\ nil) do
    adapter().update_group(group_id, group_data, scope)
  end

  @impl true
  def replace_group(group_id, group_data, scope \\ nil) do
    adapter().replace_group(group_id, group_data, scope)
  end

  @impl true
  def delete_group(group_id, scope \\ nil) do
    adapter().delete_group(group_id, scope)
  end

  @impl true
  def group_exists?(group_id, scope \\ nil) do
    adapter().group_exists?(group_id, scope)
  end

  @doc """
  Returns the configured storage adapter module.

  ## Examples

      iex> ExScim.Storage.adapter()
      ExScim.Storage.EtsStorage
  """
  def adapter do
    Application.get_env(:ex_scim, :storage_strategy, @default_storage_adapter)
  end
end
