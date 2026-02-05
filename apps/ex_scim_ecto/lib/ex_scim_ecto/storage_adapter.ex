defmodule ExScimEcto.StorageAdapter do
  @moduledoc """
  Ecto-based implementation of `ExScim.Storage.Adapter`.

  Expects the following in your application config:

      config :ex_scim,
        storage_repo: MyApp.Repo,
        user_model: MyApp.Accounts.User,
        group_model: MyApp.Groups.Group

  To preload associations:

      config :ex_scim,
        storage_repo: MyApp.Repo,
        user_model: {MyApp.Accounts.User, preload: [:roles, :organizations]},
        group_model: {MyApp.Groups.Group, preload: [:members]}

  To configure a custom lookup key (defaults to `:id`):

      config :ex_scim,
        user_model: {MyApp.Accounts.User, lookup_key: :resource_id},
        group_model: {MyApp.Groups.Group, preload: [:members], lookup_key: :uuid}

  """

  @behaviour ExScim.Storage.Adapter

  import Ecto.Query

  @impl true
  def get_user(id) do
    {_schema, _associations, lookup_key} = user_schema()
    get_resource_by(&user_schema/0, lookup_key, id)
  end

  @impl true
  def list_users(filter_ast, sort_opts, pagination_opts) do
    {user_schema, associations, _lookup_key} = user_schema()

    query =
      from(u in user_schema)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)
      |> apply_sorting(sort_opts)
      |> apply_pagination(pagination_opts)

    users =
      query
      |> repo().all()
      |> maybe_preload(repo(), associations)

    # Get total count for pagination
    count_query =
      from(u in user_schema)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)

    total = repo().aggregate(count_query, :count)

    {:ok, users, total}
  end

  @impl true
  def create_user(domain_user) when is_struct(domain_user) do
    create_user(Map.from_struct(domain_user))
  end

  def create_user(domain_user) when is_map(domain_user) do
    # Domain user struct is already validated by Users context
    {user_schema, associations, _lookup_key} = user_schema()

    changeset =
      user_schema.changeset(user_schema.__struct__(), domain_user)

    with {:ok, user} <- repo().insert(changeset) do
      {:ok, user |> maybe_preload(repo(), associations)}
    end
  end

  @impl true
  def update_user(id, domain_user) do
    {user_schema, associations, _lookup_key} = user_schema()

    with {:ok, existing} <- get_user(id) do
      attrs =
        domain_user
        |> map_from_struct()
        |> convert_preloaded_structs(associations)

      changeset = user_schema.changeset(existing, attrs)

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def replace_user(id, domain_user) do
    {user_schema, _preloads, _lookup_key} = user_schema()

    with {:ok, existing} <- get_user(id) do
      changeset = user_schema.changeset(existing, Map.from_struct(domain_user))

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def delete_user(id) do
    with {:ok, user} <- get_user(id),
         {:ok, _} <- repo().delete(user) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  @impl true
  def user_exists?(id) do
    {user_schema, _preloads, lookup_key} = user_schema()
    repo().get_by(user_schema, [{lookup_key, id}]) != nil
  end

  # Group operations
  @impl true
  def get_group(id) do
    {_schema, _associations, lookup_key} = group_schema()
    get_resource_by(&group_schema/0, lookup_key, id)
  end

  @impl true
  def list_groups(filter_ast, sort_opts, pagination_opts) do
    {group_schema, associations, _lookup_key} = group_schema()

    query =
      from(g in group_schema)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)
      |> apply_sorting(sort_opts)
      |> apply_pagination(pagination_opts)

    groups =
      query
      |> repo().all()
      |> maybe_preload(repo(), associations)

    # Get total count for pagination
    count_query =
      from(g in group_schema)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)

    total = repo().aggregate(count_query, :count)

    {:ok, groups, total}
  end

  @impl true
  def create_group(domain_group) when is_struct(domain_group) do
    create_group(Map.from_struct(domain_group))
  end

  def create_group(domain_group) when is_map(domain_group) do
    {group_schema, associations, _lookup_key} = group_schema()
    changeset = group_schema.changeset(group_schema.__struct__(), domain_group)

    with {:ok, group} <- repo().insert(changeset) do
      {:ok, group |> maybe_preload(repo(), associations)}
    end
  end

  @impl true
  def update_group(id, domain_group) do
    {group_schema, associations, _lookup_key} = group_schema()

    with {:ok, existing} <- get_group(id) do
      attrs =
        domain_group
        |> map_from_struct()
        |> convert_preloaded_structs(associations)

      changeset = group_schema.changeset(existing, attrs)

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def replace_group(id, domain_group) do
    {group_schema, _preloads, _lookup_key} = group_schema()

    with {:ok, existing} <- get_group(id) do
      changeset = group_schema.changeset(existing, Map.from_struct(domain_group))

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def delete_group(id) do
    with {:ok, group} <- get_group(id),
         {:ok, _} <- repo().delete(group) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  @impl true
  def group_exists?(id) do
    {group_schema, _preloads, lookup_key} = group_schema()
    repo().get_by(group_schema, [{lookup_key, id}]) != nil
  end

  # Private helper functions

  defp repo, do: Application.fetch_env!(:ex_scim, :storage_repo)

  defp user_schema, do: parse_model_config(:user_model)

  defp group_schema, do: parse_model_config(:group_model)

  defp parse_model_config(config_key) do
    case Application.get_env(:ex_scim, config_key) do
      {model, opts} ->
        {model, Keyword.get(opts, :preload, []), Keyword.get(opts, :lookup_key, :id)}

      model when not is_nil(model) ->
        {model, [], :id}

      nil ->
        raise ArgumentError, "Missing configuration for #{inspect(config_key)}"
    end
  end

  defp maybe_preload(nil, _repo, _preloads), do: nil
  defp maybe_preload(records, _repo, []), do: records
  defp maybe_preload(records, repo, preloads), do: repo.preload(records, preloads)

  defp get_resource_by(schema_opts_fn, field, value) do
    {resource_schema, associations, _lookup_key} = schema_opts_fn.()

    resource_schema
    |> repo().get_by([{field, value}])
    |> maybe_preload(repo(), associations)
    |> case do
      nil -> {:error, :not_found}
      resource -> {:ok, resource}
    end
  end

  defp convert_preloaded_structs(map, []), do: map

  defp convert_preloaded_structs(map, associations) do
    Map.new(map, fn {key, existing_value} ->
      value =
        if key in associations do
          map_from_struct(existing_value)
        else
          existing_value
        end

      {key, value}
    end)
  end

  defp map_from_struct(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> drop_nils()
  end

  defp map_from_struct(list) when is_list(list), do: Enum.map(list, &map_from_struct/1)

  defp map_from_struct(map), do: map

  defp drop_nils(map) do
    map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
  end

  defp apply_sorting(query, []), do: query

  defp apply_sorting(query, sort_opts) do
    case Keyword.get(sort_opts, :sort_by) do
      {sort_field, sort_direction} when is_binary(sort_field) ->
        field_atom = String.to_existing_atom(sort_field)

        case sort_direction do
          :desc -> order_by(query, [u], desc: field(u, ^field_atom))
          _ -> order_by(query, [u], asc: field(u, ^field_atom))
        end

      _ ->
        query
    end
  end

  defp apply_pagination(query, []), do: query

  defp apply_pagination(query, pagination_opts) do
    start_index = Keyword.get(pagination_opts, :start_index, 1)
    count = Keyword.get(pagination_opts, :count, 20)

    query
    |> offset(^(start_index - 1))
    |> limit(^count)
  end
end
