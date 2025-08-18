defmodule ExScim.Storage do
  @behaviour ExScim.Storage.Adapter

  @default_storage_adapter ExScim.Storage.EtsStorage

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

  @impl true
  def create_user(user_data) do
    adapter().create_user(user_data)
  end

  @impl true
  def update_user(user_id, user_data) do
    adapter().update_user(user_id, user_data)
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
  def delete_group(group_id) do
    adapter().delete_group(group_id)
  end

  @impl true
  def group_exists?(group_id) do
    adapter().group_exists?(group_id)
  end

  def adapter do
    Application.get_env(:ex_scim, :storage_strategy, @default_storage_adapter)
  end
end
