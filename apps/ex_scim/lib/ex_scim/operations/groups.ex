defmodule ExScim.Operations.Groups do
  @moduledoc "Group management context."

  alias ExScim.Groups.Mapper
  alias ExScim.Groups.Patcher
  alias ExScim.Resources.Resource
  alias ExScim.Resources.IdGenerator
  alias ExScim.Resources.Metadata
  alias ExScim.Schema.Validator
  alias ExScim.Storage

  def get_group(id, caller) do
    with {:ok, domain_group} <- Storage.get_group(id),
         {:ok, scim_group} <- Mapper.to_scim(domain_group, caller) do
      {:ok, scim_group}
    end
  end

  def list_groups_scim(caller, opts \\ %{}) do
    filter_ast = Map.get(opts, :filter)
    sort_opts = build_sort_opts(Map.get(opts, :sort_by), Map.get(opts, :sort_order))
    pagination_opts = build_pagination_opts(Map.get(opts, :start_index), Map.get(opts, :count))

    with {:ok, domain_groups, total} <-
           Storage.list_groups(filter_ast, sort_opts, pagination_opts) do
      map_all_groups(domain_groups, caller, total)
    end
  end

  def create_group_from_scim(scim_data, caller) do
    with {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, mapped_data} <- Mapper.from_scim(schema_validated_data, caller),
         data_with_id <- maybe_set_id(mapped_data),
         data_with_metadata <- Metadata.update_metadata(data_with_id, "Group"),
         {:ok, stored_group} <- Storage.create_group(data_with_metadata),
         {:ok, scim_group} <- Mapper.to_scim(stored_group, caller) do
      {:ok, scim_group}
    end
  end

  def replace_group_from_scim(group_id, scim_data, caller) do
    with {:ok, _existing_group} <- Storage.get_group(group_id),
         {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, group_struct} <- Mapper.from_scim(schema_validated_data, caller),
         group_with_id <- Resource.set_id(group_struct, group_id),
         group_with_meta <- Metadata.update_metadata(group_with_id, "Group"),
         {:ok, stored_group} <- Storage.replace_group(group_id, group_with_meta),
         {:ok, scim_group} <- Mapper.to_scim(stored_group, caller) do
      {:ok, scim_group}
    end
  end

  def patch_group_from_scim(group_id, scim_data, caller) do
    with {:ok, domain_group} <- Storage.get_group(group_id),
         {:ok, schema_validated_data} <- Validator.validate_scim_partial(scim_data, :patch),
         {:ok, patched_group} <- Patcher.patch(domain_group, schema_validated_data),
         group_with_meta <- Metadata.update_metadata(patched_group, "Group"),
         {:ok, stored_group} <- Storage.update_group(group_id, group_with_meta),
         {:ok, scim_group} <- Mapper.to_scim(stored_group, caller) do
      {:ok, scim_group}
    end
  end

  def delete_group(group_id) do
    Storage.delete_group(group_id)
  end

  defp maybe_set_id(group_struct) do
    case Resource.get_id(group_struct) do
      nil -> Resource.set_id(group_struct, IdGenerator.generate_uuid())
      _id -> group_struct
    end
  end

  defp map_all_groups(domain_groups, caller, total) do
    domain_groups
    |> Enum.reduce_while({:ok, []}, fn group, {:ok, acc} ->
      case Mapper.to_scim(group, caller) do
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
