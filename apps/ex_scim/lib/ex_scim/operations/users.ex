defmodule ExScim.Operations.Users do
  @moduledoc "User management context."

  alias ExScim.Resources.IdGenerator
  alias ExScim.Resources.Metadata
  alias ExScim.Resources.Resource
  alias ExScim.Schema.Validator
  alias ExScim.Storage
  alias ExScim.Users.Mapper
  alias ExScim.Users.Patcher

  def get_user(id, caller) do
    with {:ok, domain_user} <- Storage.get_user(id),
         {:ok, scim_user} <- Mapper.to_scim(domain_user, caller) do
      {:ok, scim_user}
    end
  end

  def list_users_scim(caller, opts \\ %{}) do
    filter_ast = Map.get(opts, :filter)
    sort_opts = build_sort_opts(Map.get(opts, :sort_by), Map.get(opts, :sort_order))
    pagination_opts = build_pagination_opts(Map.get(opts, :start_index), Map.get(opts, :count))

    with {:ok, domain_users, total} <-
           Storage.list_users(filter_ast, sort_opts, pagination_opts) do
      map_all_users(domain_users, caller, total)
    end
  end

  def create_user_from_scim(scim_data, caller) do
    with {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, mapped_data} <- Mapper.from_scim(schema_validated_data, caller),
         data_with_id <- maybe_set_id(mapped_data),
         data_with_metadata <- Metadata.update_metadata(data_with_id, "User"),
         {:ok, stored_user} <- Storage.create_user(data_with_metadata),
         {:ok, scim_user} <- Mapper.to_scim(stored_user, caller) do
      {:ok, scim_user}
    end
  end

  def replace_user_from_scim(user_id, scim_data, caller) do
    with {:ok, _existing_user} <- Storage.get_user(user_id),
         {:ok, schema_validated_data} <- Validator.validate_scim_schema(scim_data),
         {:ok, user_struct} <- Mapper.from_scim(schema_validated_data, caller),
         user_with_id <- Resource.set_id(user_struct, user_id),
         user_with_meta <- Metadata.update_metadata(user_with_id, "User"),
         {:ok, stored_user} <- Storage.replace_user(user_id, user_with_meta),
         {:ok, scim_user} <- Mapper.to_scim(stored_user, caller) do
      {:ok, scim_user}
    end
  end

  def patch_user_from_scim(user_id, scim_data, caller) do
    with {:ok, domain_user} <- Storage.get_user(user_id),
         {:ok, schema_validated_data} <- Validator.validate_scim_partial(scim_data, :patch),
         {:ok, patched_user} <- Patcher.patch(domain_user, schema_validated_data),
         user_with_meta <- Metadata.update_metadata(patched_user, "User"),
         {:ok, stored_user} <- Storage.update_user(user_id, user_with_meta),
         {:ok, scim_user} <- Mapper.to_scim(stored_user, caller) do
      {:ok, scim_user}
    end
  end

  def delete_user(user_id) do
    Storage.delete_user(user_id)
  end

  defp maybe_set_id(user_struct) do
    case Resource.get_id(user_struct) do
      nil -> Resource.set_id(user_struct, IdGenerator.generate_uuid())
      _id -> user_struct
    end
  end

  defp map_all_users(domain_users, caller, total) do
    domain_users
    |> Enum.reduce_while({:ok, []}, fn user, {:ok, acc} ->
      case Mapper.to_scim(user, caller) do
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
