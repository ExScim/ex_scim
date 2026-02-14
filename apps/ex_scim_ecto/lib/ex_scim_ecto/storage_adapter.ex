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

  To map SCIM complex attribute paths to DB columns:

      config :ex_scim,
        user_model: {MyApp.Accounts.User,
          filter_mapping: %{
            "emails.value" => :email,
            "name.givenName" => :given_name
          }}

  To enable multi-tenant scoping via a discriminator column:

      config :ex_scim,
        user_model: {MyApp.Accounts.User, lookup_key: :id, tenant_key: :organization_id},
        group_model: {MyApp.Groups.Group, tenant_key: :organization_id}

  When `tenant_key` is configured and `scope.tenant_id` is not nil, all queries
  include a WHERE clause on the tenant column, and creates inject the tenant_id.

  See also `ExScim.Resources.Resource`.
  """

  @behaviour ExScim.Storage.Adapter

  import Ecto.Query
  require Logger

  @impl true
  def get_user(id, scope \\ nil) do
    {_schema, _associations, lookup_key, _filter_mapping, tenant_key} = user_schema()
    get_resource_by(&user_schema/0, lookup_key, id, tenant_key, scope)
  end

  @impl true
  def list_users(filter_ast, sort_opts, pagination_opts, scope \\ nil) do
    {user_schema, associations, _lookup_key, filter_mapping, tenant_key} = user_schema()

    filter_opts = [
      filter_mapping: filter_mapping,
      schema_fields: user_schema.__schema__(:fields)
    ]

    query =
      from(u in user_schema)
      |> apply_tenant_scope(tenant_key, scope)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast, filter_opts)
      |> apply_sorting(sort_opts)
      |> apply_pagination(pagination_opts)

    users =
      query
      |> repo().all()
      |> maybe_preload(repo(), associations)

    # Get total count for pagination
    count_query =
      from(u in user_schema)
      |> apply_tenant_scope(tenant_key, scope)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast, filter_opts)

    total = repo().aggregate(count_query, :count)

    {:ok, users, total}
  rescue
    e in ArgumentError ->
      Logger.warning("Invalid SCIM filter: #{Exception.message(e)}")
      {:error, {:invalid_filter, Exception.message(e)}}

    e ->
      Logger.error(
        "Query execution failed: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      {:error, :query_error}
  end

  @impl true
  def create_user(domain_user, scope \\ nil)

  def create_user(domain_user, scope) when is_struct(domain_user) do
    create_user_map(Map.from_struct(domain_user), scope)
  end

  def create_user(domain_user, scope) when is_map(domain_user) do
    create_user_map(domain_user, scope)
  end

  defp create_user_map(domain_user, scope) do
    {user_schema, associations, _lookup_key, _filter_mapping, tenant_key} = user_schema()

    domain_user = inject_tenant(domain_user, tenant_key, scope)

    changeset =
      user_schema.changeset(user_schema.__struct__(), domain_user)

    with {:ok, user} <- repo().insert(changeset) do
      {:ok, user |> maybe_preload(repo(), associations)}
    end
  end

  @impl true
  def update_user(id, domain_user, scope \\ nil) do
    {user_schema, associations, _lookup_key, _filter_mapping, _tenant_key} = user_schema()

    with {:ok, existing} <- get_user(id, scope) do
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
  def replace_user(id, domain_user, scope \\ nil) do
    {user_schema, _preloads, _lookup_key, _filter_mapping, _tenant_key} = user_schema()

    with {:ok, existing} <- get_user(id, scope) do
      changeset = user_schema.changeset(existing, Map.from_struct(domain_user))

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def delete_user(id, scope \\ nil) do
    with {:ok, user} <- get_user(id, scope),
         {:ok, _} <- repo().delete(user) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  @impl true
  def user_exists?(id, scope \\ nil) do
    {user_schema, _preloads, lookup_key, _filter_mapping, tenant_key} = user_schema()

    query = from(r in user_schema, where: field(r, ^lookup_key) == ^id)
    query = apply_tenant_scope(query, tenant_key, scope)

    repo().aggregate(query, :count) > 0
  end

  # Group operations
  @impl true
  def get_group(id, scope \\ nil) do
    {_schema, _associations, lookup_key, _filter_mapping, tenant_key} = group_schema()
    get_resource_by(&group_schema/0, lookup_key, id, tenant_key, scope)
  end

  @impl true
  def list_groups(filter_ast, sort_opts, pagination_opts, scope \\ nil) do
    {group_schema, associations, _lookup_key, filter_mapping, tenant_key} = group_schema()

    filter_opts = [
      filter_mapping: filter_mapping,
      schema_fields: group_schema.__schema__(:fields)
    ]

    query =
      from(g in group_schema)
      |> apply_tenant_scope(tenant_key, scope)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast, filter_opts)
      |> apply_sorting(sort_opts)
      |> apply_pagination(pagination_opts)

    groups =
      query
      |> repo().all()
      |> maybe_preload(repo(), associations)

    # Get total count for pagination
    count_query =
      from(g in group_schema)
      |> apply_tenant_scope(tenant_key, scope)
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast, filter_opts)

    total = repo().aggregate(count_query, :count)

    {:ok, groups, total}
  rescue
    e in ArgumentError ->
      Logger.warning("Invalid SCIM filter: #{Exception.message(e)}")
      {:error, {:invalid_filter, Exception.message(e)}}

    e ->
      Logger.error(
        "Query execution failed: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      {:error, :query_error}
  end

  @impl true
  def create_group(domain_group, scope \\ nil)

  def create_group(domain_group, scope) when is_struct(domain_group) do
    create_group_map(Map.from_struct(domain_group), scope)
  end

  def create_group(domain_group, scope) when is_map(domain_group) do
    create_group_map(domain_group, scope)
  end

  defp create_group_map(domain_group, scope) do
    {group_schema, associations, _lookup_key, _filter_mapping, tenant_key} = group_schema()

    domain_group = inject_tenant(domain_group, tenant_key, scope)

    changeset = group_schema.changeset(group_schema.__struct__(), domain_group)

    with {:ok, group} <- repo().insert(changeset) do
      {:ok, group |> maybe_preload(repo(), associations)}
    end
  end

  @impl true
  def update_group(id, domain_group, scope \\ nil) do
    {group_schema, associations, _lookup_key, _filter_mapping, _tenant_key} = group_schema()

    with {:ok, existing} <- get_group(id, scope) do
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
  def replace_group(id, domain_group, scope \\ nil) do
    {group_schema, _preloads, _lookup_key, _filter_mapping, _tenant_key} = group_schema()

    with {:ok, existing} <- get_group(id, scope) do
      changeset = group_schema.changeset(existing, Map.from_struct(domain_group))

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def delete_group(id, scope \\ nil) do
    with {:ok, group} <- get_group(id, scope),
         {:ok, _} <- repo().delete(group) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  @impl true
  def group_exists?(id, scope \\ nil) do
    {group_schema, _preloads, lookup_key, _filter_mapping, tenant_key} = group_schema()

    query = from(r in group_schema, where: field(r, ^lookup_key) == ^id)
    query = apply_tenant_scope(query, tenant_key, scope)

    repo().aggregate(query, :count) > 0
  end

  # Private helper functions

  defp repo, do: Application.fetch_env!(:ex_scim, :storage_repo)

  defp user_schema, do: parse_model_config(:user_model)

  defp group_schema, do: parse_model_config(:group_model)

  defp parse_model_config(config_key) do
    case Application.get_env(:ex_scim, config_key) do
      {model, opts} ->
        {model,
         Keyword.get(opts, :preload, []),
         Keyword.get(opts, :lookup_key, :id),
         Keyword.get(opts, :filter_mapping, %{}),
         Keyword.get(opts, :tenant_key)}

      model when not is_nil(model) ->
        {model, [], :id, %{}, nil}

      nil ->
        raise ArgumentError, "Missing configuration for #{inspect(config_key)}"
    end
  end

  defp maybe_preload(nil, _repo, _preloads), do: nil
  defp maybe_preload(records, _repo, []), do: records
  defp maybe_preload(records, repo, preloads), do: repo.preload(records, preloads)

  defp get_resource_by(schema_opts_fn, field, value, tenant_key, scope) do
    {resource_schema, associations, _lookup_key, _filter_mapping, _tenant_key} = schema_opts_fn.()

    query = from(r in resource_schema, where: field(r, ^field) == ^value)
    query = apply_tenant_scope(query, tenant_key, scope)

    query
    |> repo().one()
    |> maybe_preload(repo(), associations)
    |> case do
      nil -> {:error, :not_found}
      resource -> {:ok, resource}
    end
  end

  defp apply_tenant_scope(query, _tenant_key, nil), do: query
  defp apply_tenant_scope(query, nil, _scope), do: query
  defp apply_tenant_scope(query, _tenant_key, %ExScim.Scope{tenant_id: nil}), do: query

  defp apply_tenant_scope(query, tenant_key, %ExScim.Scope{tenant_id: tenant_id}) do
    where(query, [r], field(r, ^tenant_key) == ^tenant_id)
  end

  defp inject_tenant(data, _tenant_key, nil), do: data
  defp inject_tenant(data, nil, _scope), do: data
  defp inject_tenant(data, _tenant_key, %ExScim.Scope{tenant_id: nil}), do: data

  defp inject_tenant(data, tenant_key, %ExScim.Scope{tenant_id: tenant_id}) do
    Map.put(data, tenant_key, tenant_id)
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
