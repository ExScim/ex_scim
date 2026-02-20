defmodule ExScim.Operations.Groups do
  @moduledoc """
  Orchestration layer for SCIM group operations.

  Ties together schema validation, domain mapping, lifecycle hooks, and storage
  for each SCIM operation (GET, LIST, POST, PUT, PATCH, DELETE). This is the
  primary entry point used by controllers to execute group operations.
  """

  alias ExScim.Groups.Mapper
  alias ExScim.Groups.Patcher
  alias ExScim.Lifecycle
  alias ExScim.Resources.Resource
  alias ExScim.Resources.IdGenerator
  alias ExScim.Resources.Metadata
  alias ExScim.Schema.Validator
  alias ExScim.Storage

  @doc "Retrieves a group by ID, applying lifecycle hooks and SCIM mapping. Returns `{:ok, scim_group}` or `{:error, reason}`."
  def get_group(id, scope) do
    with :ok <- Lifecycle.before_get(:group, id, scope),
         {:ok, domain_group} <- Storage.get_group(id, scope),
         {:ok, scim_group} <- Mapper.to_scim(domain_group, scope) do
      Lifecycle.after_get(:group, scim_group, scope)
      {:ok, scim_group}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:get, :group, error, scope)
        error
    end
  end

  @doc """
  Lists groups as SCIM resources with filtering, sorting, and pagination.

  `opts` may include `:filter`, `:sort_by`, `:sort_order`, `:start_index`, and `:count`.
  Returns `{:ok, scim_groups, total_count}`.
  """
  def list_groups_scim(scope, opts \\ %{}) do
    filter_ast = Map.get(opts, :filter)
    sort_opts = build_sort_opts(Map.get(opts, :sort_by), Map.get(opts, :sort_order))
    pagination_opts = build_pagination_opts(Map.get(opts, :start_index), Map.get(opts, :count))

    with {:ok, domain_groups, total} <-
           Storage.list_groups(filter_ast, sort_opts, pagination_opts, scope) do
      map_all_groups(domain_groups, scope, total)
    end
  end

  @doc """
  Creates a group from a SCIM JSON payload.

  Validates the schema, maps to a domain struct, generates an ID if needed,
  runs lifecycle hooks, stores, and maps back to SCIM.
  Returns `{:ok, scim_group}` or `{:error, reason}`.
  """
  def create_group_from_scim(scim_data, scope) do
    with {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, mapped_data} <- Mapper.from_scim(schema_validated_data, scope),
         data_with_id <- maybe_set_id(mapped_data),
         data_with_metadata <- Metadata.update_metadata(data_with_id, "Group"),
         {:ok, hooked_data} <- Lifecycle.before_create(:group, data_with_metadata, scope),
         {:ok, stored_group} <- Storage.create_group(hooked_data, scope),
         {:ok, scim_group} <- Mapper.to_scim(stored_group, scope) do
      Lifecycle.after_create(:group, scim_group, scope)
      {:ok, scim_group}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:create, :group, error, scope)
        error
    end
  end

  @doc """
  Fully replaces a group (PUT) from a SCIM JSON payload.

  Verifies the group exists, validates, maps, runs lifecycle hooks, and stores.
  Returns `{:ok, scim_group}` or `{:error, reason}`.
  """
  def replace_group_from_scim(group_id, scim_data, scope) do
    with {:ok, _existing_group} <- Storage.get_group(group_id, scope),
         {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, group_struct} <- Mapper.from_scim(schema_validated_data, scope),
         group_with_id <- Resource.set_id(group_struct, group_id),
         group_with_meta <- Metadata.update_metadata(group_with_id, "Group"),
         {:ok, hooked_data} <-
           Lifecycle.before_replace(:group, group_id, group_with_meta, scope),
         {:ok, stored_group} <- Storage.replace_group(group_id, hooked_data, scope),
         {:ok, scim_group} <- Mapper.to_scim(stored_group, scope) do
      Lifecycle.after_replace(:group, scim_group, scope)
      {:ok, scim_group}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:replace, :group, error, scope)
        error
    end
  end

  @doc """
  Applies a SCIM PATCH operation to an existing group.

  Fetches the group, validates the patch payload, applies patch operations,
  runs lifecycle hooks, and stores.
  Returns `{:ok, scim_group}` or `{:error, reason}`.
  """
  def patch_group_from_scim(group_id, scim_data, scope) do
    with {:ok, domain_group} <- Storage.get_group(group_id, scope),
         {:ok, schema_validated_data} <- Validator.validate_scim_partial(scim_data, :patch),
         {:ok, patched_group} <- Patcher.patch(domain_group, schema_validated_data),
         group_with_meta <- Metadata.update_metadata(patched_group, "Group"),
         {:ok, hooked_data} <-
           Lifecycle.before_patch(:group, group_id, group_with_meta, scope),
         {:ok, stored_group} <- Storage.update_group(group_id, hooked_data, scope),
         {:ok, scim_group} <- Mapper.to_scim(stored_group, scope) do
      Lifecycle.after_patch(:group, scim_group, scope)
      {:ok, scim_group}
    else
      {:error, _} = error ->
        Lifecycle.on_error(:patch, :group, error, scope)
        error
    end
  end

  @doc "Deletes a group by ID with lifecycle hooks. Returns `:ok` or `{:error, reason}`."
  def delete_group(group_id, scope) do
    with :ok <- Lifecycle.before_delete(:group, group_id, scope),
         :ok <- Storage.delete_group(group_id, scope) do
      Lifecycle.after_delete(:group, group_id, scope)
      :ok
    else
      {:error, _} = error ->
        Lifecycle.on_error(:delete, :group, error, scope)
        error
    end
  end

  defp maybe_set_id(group_struct) do
    case Resource.get_id(group_struct) do
      nil -> Resource.set_id(group_struct, IdGenerator.generate_uuid())
      _id -> group_struct
    end
  end

  defp map_all_groups(domain_groups, scope, total) do
    domain_groups
    |> Enum.reduce_while({:ok, []}, fn group, {:ok, acc} ->
      case Mapper.to_scim(group, scope) do
        {:ok, scim_group} -> {:cont, {:ok, [scim_group | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, scim_groups} -> {:ok, Enum.reverse(scim_groups), total}
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
