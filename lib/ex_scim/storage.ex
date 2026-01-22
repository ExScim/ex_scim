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
  def get_user(user_id) do
    adapter().get_user(user_id)
  end

  @impl true
  def get_user_by_username(binary) do
    adapter().get_user_by_username(binary)
  end

  @impl true
  def get_user_by_external_id(binary) do
    adapter().get_user_by_external_id(binary)
  end

  @impl true
  def list_users(filter_ast, sort_opts, pagination_opts) do
    adapter().list_users(filter_ast, sort_opts, pagination_opts)
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
  def create_user(user_data) do
    adapter().create_user(user_data)
  end

  @impl true
  def update_user(user_id, user_data) do
    adapter().update_user(user_id, user_data)
  end

  @impl true
  def replace_user(user_id, user_data) do
    adapter().replace_user(user_id, user_data)
  end

  @impl true
  def delete_user(user_id) do
    adapter().delete_user(user_id)
  end

  @impl true
  def user_exists?(user_id) do
    adapter().user_exists?(user_id)
  end

  # Group operations
  @impl true
  def get_group(group_id) do
    adapter().get_group(group_id)
  end

  @impl true
  def get_group_by_display_name(display_name) do
    adapter().get_group_by_display_name(display_name)
  end

  @impl true
  def get_group_by_external_id(external_id) do
    adapter().get_group_by_external_id(external_id)
  end

  @impl true
  def list_groups(filter_ast, sort_opts, pagination_opts) do
    adapter().list_groups(filter_ast, sort_opts, pagination_opts)
  end

  @impl true
  def create_group(group_data) do
    adapter().create_group(group_data)
  end

  @impl true
  def update_group(group_id, group_data) do
    adapter().update_group(group_id, group_data)
  end

  @impl true
  def replace_group(group_id, group_data) do
    adapter().replace_group(group_id, group_data)
  end

  @impl true
  def delete_group(group_id) do
    adapter().delete_group(group_id)
  end

  @impl true
  def group_exists?(group_id) do
    adapter().group_exists?(group_id)
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
