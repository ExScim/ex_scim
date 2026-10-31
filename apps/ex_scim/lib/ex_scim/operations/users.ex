defmodule ExScim.Operations.Users do
  @moduledoc """
  Orchestration layer for SCIM user operations.

  Ties together schema validation, domain mapping, lifecycle hooks, and storage
  for each SCIM operation (GET, LIST, POST, PUT, PATCH, DELETE). This is the
  primary entry point used by controllers to execute user operations.
  """

  alias ExScim.Config
  alias ExScim.Lifecycle
  alias ExScim.Resources.IdGenerator
  alias ExScim.Resources.Metadata
  alias ExScim.Resources.Resource
  alias ExScim.Schema.PatchValidator
  alias ExScim.Schema.Validator
  alias ExScim.Storage
  alias ExScim.Users.Mapper
  alias ExScim.Users.Patcher

  @doc "Retrieves a user by ID, applying lifecycle hooks and SCIM mapping. Returns `{:ok, scim_user}` or `{:error, reason}`."
  def get_user(id, scope) do
    with :ok <- Lifecycle.before_get(:user, id, scope),
         {:ok, domain_user} <- Storage.get_user(id, scope),
         {:ok, scim_user} <- to_scim(domain_user, scope) do
      Lifecycle.after_get(:user, scim_user, scope)
      {:ok, scim_user}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:get, :user, error, scope)
        error
    end
  end

  @doc """
  Lists users as SCIM resources with filtering, sorting, and pagination.

  `opts` may include `:filter`, `:sort_by`, `:sort_order`, `:start_index`, and `:count`.
  Returns `{:ok, scim_users, total_count}`.
  """
  def list_users_scim(scope, opts \\ %{}) do
    filter_ast = Map.get(opts, :filter)
    sort_opts = build_sort_opts(Map.get(opts, :sort_by), Map.get(opts, :sort_order))
    pagination_opts = build_pagination_opts(Map.get(opts, :start_index), Map.get(opts, :count))

    with {:ok, domain_users, total} <-
           Storage.list_users(filter_ast, sort_opts, pagination_opts, scope) do
      map_all_users(domain_users, scope, total)
    end
  end

  @doc """
  Creates a user from a SCIM JSON payload.

  Validates the schema, maps to a domain struct, generates an ID if needed,
  runs lifecycle hooks, stores, and maps back to SCIM.
  Returns `{:ok, scim_user}` or `{:error, reason}`.
  """
  def create_user_from_scim(scim_data, scope) do
    with {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, mapped_data} <- Mapper.from_scim(schema_validated_data, scope),
         data_with_id <- maybe_set_id(mapped_data),
         data_with_metadata <- Metadata.update_metadata(data_with_id, "User"),
         {:ok, hooked_data} <- Lifecycle.before_create(:user, data_with_metadata, scope),
         {:ok, stored_user} <-
           store(:create, scope, fn -> Storage.create_user(hooked_data, scope) end),
         {:ok, scim_user} <- to_scim(stored_user, scope) do
      Lifecycle.after_create(:user, scim_user, scope)
      {:ok, scim_user}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:create, :user, error, scope)
        error
    end
  end

  @doc """
  Fully replaces a user (PUT) from a SCIM JSON payload.

  Verifies the user exists, validates, maps, runs lifecycle hooks, and stores.
  Returns `{:ok, scim_user}` or `{:error, reason}`.
  """
  def replace_user_from_scim(user_id, scim_data, scope) do
    with {:ok, existing_user} <- Storage.get_user(user_id, scope),
         {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, user_struct} <- Mapper.from_scim(schema_validated_data, scope),
         user_with_id <- Resource.set_id(user_struct, user_id),
         user_with_created <-
           Map.put(user_with_id, :meta_created, Map.get(existing_user, :meta_created)),
         user_with_meta <- Metadata.update_metadata(user_with_created, "User"),
         {:ok, hooked_data} <- Lifecycle.before_replace(:user, user_id, user_with_meta, scope),
         {:ok, stored_user} <-
           store(:replace, scope, fn -> Storage.replace_user(user_id, hooked_data, scope) end),
         {:ok, scim_user} <- to_scim(stored_user, scope) do
      Lifecycle.after_replace(:user, scim_user, scope)
      {:ok, scim_user}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:replace, :user, error, scope)
        error
    end
  end

  @doc """
  Applies a SCIM PATCH to an existing user.

  Paths are checked against the User schemas first. The operations then run
  on the mapper's SCIM representation of the stored user, and the result is
  mapped back and stored like a PUT.

  Unknown attributes return `{:error, {:invalid_patch, :invalid_path, message}}`.
  Changing a read-only or immutable attribute returns `:mutability`. Values
  equal to the current ones are ignored.
  """
  def patch_user_from_scim(user_id, scim_data, scope) do
    with {:ok, patch_ops} <- PatchValidator.validate(scim_data, "User"),
         {:ok, existing_user} <- Storage.get_user(user_id, scope),
         {:ok, current} <- Mapper.to_scim(existing_user, scope),
         {:ok, patch_ops} <- PatchValidator.validate_changes(patch_ops, current, "User"),
         {:ok, patched} <- Patcher.patch(current, patch_ops),
         {:ok, user_struct} <- Mapper.from_scim(patched, scope),
         user_with_id <- Resource.set_id(user_struct, user_id),
         user_with_created <-
           Map.put(user_with_id, :meta_created, Map.get(existing_user, :meta_created)),
         user_with_meta <- Metadata.update_metadata(user_with_created, "User"),
         {:ok, hooked_data} <- Lifecycle.before_patch(:user, user_id, user_with_meta, scope),
         {:ok, stored_user} <-
           store(:patch, scope, fn -> Storage.update_user(user_id, hooked_data, scope) end),
         {:ok, scim_user} <- to_scim(stored_user, scope) do
      Lifecycle.after_patch(:user, scim_user, scope)
      {:ok, scim_user}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:patch, :user, error, scope)
        error
    end
  end

  @doc "Deletes a user by ID with lifecycle hooks. Returns `:ok` or `{:error, reason}`."
  def delete_user(user_id, scope) do
    with :ok <- Lifecycle.before_delete(:user, user_id, scope),
         :ok <- delete(user_id, scope) do
      Lifecycle.after_delete(:user, user_id, scope)
      :ok
    else
      {:error, _} = error ->
        Lifecycle.on_error(:delete, :user, error, scope)
        error
    end
  end

  defp store(operation, scope, write) do
    Storage.transaction(fn ->
      with {:ok, stored} <- write.(),
           :ok <- Lifecycle.before_commit(operation, :user, stored, scope) do
        {:ok, stored}
      end
    end)
  end

  defp delete(user_id, scope) do
    Storage.transaction(fn ->
      with :ok <- Storage.delete_user(user_id, scope) do
        Lifecycle.before_commit(:delete, :user, user_id, scope)
      end
    end)
  end

  defp to_scim(user, scope, base_url \\ nil) do
    case Resource.get_id(user) do
      nil ->
        Mapper.to_scim(user, scope)

      id ->
        base_url = base_url || Config.scim_base_url(scope)
        Mapper.to_scim(user, scope, location: "#{base_url}/Users/#{id}")
    end
  end

  defp maybe_set_id(user_struct) do
    case Resource.get_id(user_struct) do
      nil -> Resource.set_id(user_struct, IdGenerator.generate_uuid())
      _id -> user_struct
    end
  end

  defp map_all_users(domain_users, scope, total) do
    base_url = Config.scim_base_url(scope)

    domain_users
    |> Enum.reduce_while({:ok, []}, fn user, {:ok, acc} ->
      case to_scim(user, scope, base_url) do
        {:ok, scim_user} -> {:cont, {:ok, [scim_user | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, scim_users} -> {:ok, Enum.reverse(scim_users), total}
      error -> error
    end
  end

  defp build_sort_opts(nil, _), do: []

  defp build_sort_opts(sort_field, sort_order) do
    direction =
      case sort_order do
        :descending -> :desc
        _ -> :asc
      end

    [sort_by: {sort_field, direction}]
  end

  defp build_pagination_opts(start_index, count) do
    [start_index: start_index || 1, count: count || 20]
  end
end
