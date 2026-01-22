defmodule ExScim.Storage.EtsStorage do
  @moduledoc "ETS-based storage implementation."

  @behaviour ExScim.Storage.Adapter

  use GenServer

  @table_name :scim_users
  @username_index :scim_users_username
  @external_id_index :scim_users_external_id

  @groups_table_name :scim_groups
  @groups_display_name_index :scim_groups_display_name
  @groups_external_id_index :scim_groups_external_id

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_user(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, user_data}] -> {:ok, user_data}
      [] -> {:error, :not_found}
    end
  end

  def get_user_by_username(username) do
    case :ets.lookup(@username_index, username) do
      [{^username, user_id}] -> get_user(user_id)
      [] -> {:error, :not_found}
    end
  end

  def get_user_by_external_id(external_id) do
    case :ets.lookup(@external_id_index, external_id) do
      [{^external_id, user_id}] -> get_user(user_id)
      [] -> {:error, :not_found}
    end
  end

  def list_users(filter_ast \\ nil, sort_opts \\ [], pagination_opts \\ []) do
    GenServer.call(__MODULE__, {:list_users, filter_ast, sort_opts, pagination_opts})
  end

  def create_user(user_data) do
    GenServer.call(__MODULE__, {:create_user, user_data})
  end

  def update_user(user_id, user_data) do
    GenServer.call(__MODULE__, {:update_user, user_id, user_data})
  end

  def replace_user(user_id, user_data) do
    GenServer.call(__MODULE__, {:replace_user, user_id, user_data})
  end

  def delete_user(user_id) do
    GenServer.call(__MODULE__, {:delete_user, user_id})
  end

  def user_exists?(user_id) do
    case get_user(user_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  def clear_all() do
    GenServer.call(__MODULE__, :clear_all)
  end

  # Group operations
  def get_group(id) do
    case :ets.lookup(@groups_table_name, id) do
      [{^id, group_data}] -> {:ok, group_data}
      [] -> {:error, :not_found}
    end
  end

  def get_group_by_display_name(display_name) do
    case :ets.lookup(@groups_display_name_index, display_name) do
      [{^display_name, group_id}] -> get_group(group_id)
      [] -> {:error, :not_found}
    end
  end

  def get_group_by_external_id(external_id) do
    case :ets.lookup(@groups_external_id_index, external_id) do
      [{^external_id, group_id}] -> get_group(group_id)
      [] -> {:error, :not_found}
    end
  end

  def list_groups(filter_ast \\ nil, sort_opts \\ [], pagination_opts \\ []) do
    GenServer.call(__MODULE__, {:list_groups, filter_ast, sort_opts, pagination_opts})
  end

  def create_group(group_data) do
    GenServer.call(__MODULE__, {:create_group, group_data})
  end

  def update_group(group_id, group_data) do
    GenServer.call(__MODULE__, {:update_group, group_id, group_data})
  end

  def replace_group(group_id, group_data) do
    GenServer.call(__MODULE__, {:replace_group, group_id, group_data})
  end

  def delete_group(group_id) do
    GenServer.call(__MODULE__, {:delete_group, group_id})
  end

  def group_exists?(group_id) do
    case get_group(group_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  ## GenServer Callbacks

  def init(_opts) do
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@username_index, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@external_id_index, [:set, :public, :named_table, {:read_concurrency, true}])

    :ets.new(@groups_table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@groups_display_name_index, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@groups_external_id_index, [:set, :public, :named_table, {:read_concurrency, true}])

    {:ok, %{}}
  end

  def handle_call({:list_users, filter_ast, sort_opts, pagination_opts}, _from, state) do
    users =
      @table_name
      |> :ets.tab2list()
      |> Enum.map(fn {_id, user_data} -> user_data end)
      |> ExScim.QueryFilter.EtsQueryFilter.apply_filter(filter_ast)
      |> apply_sorting(sort_opts)

    total_count = length(users)
    paginated_users = apply_pagination(users, pagination_opts)

    {:reply, {:ok, paginated_users, total_count}, state}
  end

  def handle_call({:create_user, user_data}, _from, state) do
    user_id = user_data["id"] || generate_id()
    username = user_data["userName"]
    external_id = user_data["externalId"]

    with :ok <- validate_unique_constraints(user_id, username, external_id),
         updated_user_data <- Map.put(user_data, "id", user_id),
         :ok <- store_user(user_id, updated_user_data, username, external_id) do
      {:reply, {:ok, updated_user_data}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_user, user_id, user_data}, _from, state) do
    case get_user(user_id) do
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}

      {:ok, existing_user} ->
        new_username = user_data["userName"]
        new_external_id = user_data["externalId"]
        old_username = existing_user["userName"]
        old_external_id = existing_user["externalId"]

        with :ok <-
               validate_update_constraints(
                 user_id,
                 new_username,
                 new_external_id,
                 old_username,
                 old_external_id
               ),
             updated_user_data <- Map.put(user_data, "id", user_id),
             :ok <-
               update_indexes(
                 user_id,
                 new_username,
                 new_external_id,
                 old_username,
                 old_external_id
               ),
             true <- :ets.insert(@table_name, {user_id, updated_user_data}) do
          {:reply, {:ok, updated_user_data}, state}
        else
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:replace_user, user_id, user_data}, _from, state) do
    case get_user(user_id) do
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}

      {:ok, existing_user} ->
        new_username = user_data["userName"]
        new_external_id = user_data["externalId"]
        old_username = existing_user["userName"]
        old_external_id = existing_user["externalId"]

        with :ok <-
               validate_update_constraints(
                 user_id,
                 new_username,
                 new_external_id,
                 old_username,
                 old_external_id
               ),
             updated_user_data <- Map.put(user_data, "id", user_id),
             :ok <-
               update_indexes(
                 user_id,
                 new_username,
                 new_external_id,
                 old_username,
                 old_external_id
               ),
             true <- :ets.insert(@table_name, {user_id, updated_user_data}) do
          {:reply, {:ok, updated_user_data}, state}
        else
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:delete_user, user_id}, _from, state) do
    case get_user(user_id) do
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}

      {:ok, user_data} ->
        username = user_data["userName"]
        external_id = user_data["externalId"]

        :ets.delete(@table_name, user_id)
        if username, do: :ets.delete(@username_index, username)
        if external_id, do: :ets.delete(@external_id_index, external_id)

        {:reply, :ok, state}
    end
  end

  def handle_call(:clear_all, _from, state) do
    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(@username_index)
    :ets.delete_all_objects(@external_id_index)
    :ets.delete_all_objects(@groups_table_name)
    :ets.delete_all_objects(@groups_display_name_index)
    :ets.delete_all_objects(@groups_external_id_index)
    {:reply, :ok, state}
  end

  # Group GenServer handlers
  def handle_call({:list_groups, filter_ast, sort_opts, pagination_opts}, _from, state) do
    groups =
      @groups_table_name
      |> :ets.tab2list()
      |> Enum.map(fn {_id, group_data} -> group_data end)
      |> ExScim.QueryFilter.EtsQueryFilter.apply_filter(filter_ast)
      |> apply_sorting(sort_opts)

    total_count = length(groups)
    paginated_groups = apply_pagination(groups, pagination_opts)

    {:reply, {:ok, paginated_groups, total_count}, state}
  end

  def handle_call({:create_group, group_data}, _from, state) do
    group_id = group_data["id"] || generate_id()
    display_name = group_data["displayName"]
    external_id = group_data["externalId"]

    with :ok <- validate_group_unique_constraints(group_id, display_name, external_id),
         updated_group_data <- Map.put(group_data, "id", group_id),
         :ok <- store_group(group_id, updated_group_data, display_name, external_id) do
      {:reply, {:ok, updated_group_data}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_group, group_id, group_data}, _from, state) do
    case get_group(group_id) do
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}

      {:ok, existing_group} ->
        new_display_name = group_data["displayName"]
        new_external_id = group_data["externalId"]
        old_display_name = existing_group["displayName"]
        old_external_id = existing_group["externalId"]

        with :ok <-
               validate_group_update_constraints(
                 group_id,
                 new_display_name,
                 new_external_id,
                 old_display_name,
                 old_external_id
               ),
             updated_group_data <- Map.put(group_data, "id", group_id),
             :ok <-
               update_group_indexes(
                 group_id,
                 new_display_name,
                 new_external_id,
                 old_display_name,
                 old_external_id
               ),
             true <- :ets.insert(@groups_table_name, {group_id, updated_group_data}) do
          {:reply, {:ok, updated_group_data}, state}
        else
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:replace_group, group_id, group_data}, _from, state) do
    case get_group(group_id) do
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}

      {:ok, existing_group} ->
        new_display_name = group_data["displayName"]
        new_external_id = group_data["externalId"]
        old_display_name = existing_group["displayName"]
        old_external_id = existing_group["externalId"]

        with :ok <-
               validate_group_update_constraints(
                 group_id,
                 new_display_name,
                 new_external_id,
                 old_display_name,
                 old_external_id
               ),
             updated_group_data <- Map.put(group_data, "id", group_id),
             :ok <-
               update_group_indexes(
                 group_id,
                 new_display_name,
                 new_external_id,
                 old_display_name,
                 old_external_id
               ),
             true <- :ets.insert(@groups_table_name, {group_id, updated_group_data}) do
          {:reply, {:ok, updated_group_data}, state}
        else
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:delete_group, group_id}, _from, state) do
    case get_group(group_id) do
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}

      {:ok, group_data} ->
        display_name = group_data["displayName"]
        external_id = group_data["externalId"]

        :ets.delete(@groups_table_name, group_id)
        if display_name, do: :ets.delete(@groups_display_name_index, display_name)
        if external_id, do: :ets.delete(@groups_external_id_index, external_id)

        {:reply, :ok, state}
    end
  end

  ## Private Functions

  defp generate_id, do: ExScim.Resources.IdGenerator.generate_uuid()

  defp validate_unique_constraints(user_id, username, external_id) do
    cond do
      user_exists?(user_id) ->
        {:error, :user_id_taken}

      username && match?({:ok, _}, get_user_by_username(username)) ->
        {:error, :username_taken}

      external_id && match?({:ok, _}, get_user_by_external_id(external_id)) ->
        {:error, :external_id_taken}

      true ->
        :ok
    end
  end

  defp validate_update_constraints(
         _user_id,
         new_username,
         new_external_id,
         old_username,
         old_external_id
       ) do
    cond do
      new_username != old_username && new_username &&
          match?({:ok, _}, get_user_by_username(new_username)) ->
        {:error, :username_taken}

      new_external_id != old_external_id && new_external_id &&
          match?({:ok, _}, get_user_by_external_id(new_external_id)) ->
        {:error, :external_id_taken}

      true ->
        :ok
    end
  end

  defp store_user(user_id, user_data, username, external_id) do
    :ets.insert(@table_name, {user_id, user_data})
    if username, do: :ets.insert(@username_index, {username, user_id})
    if external_id, do: :ets.insert(@external_id_index, {external_id, user_id})
    :ok
  end

  defp update_indexes(user_id, new_username, new_external_id, old_username, old_external_id) do
    if old_username != new_username do
      if old_username, do: :ets.delete(@username_index, old_username)
      if new_username, do: :ets.insert(@username_index, {new_username, user_id})
    end

    if old_external_id != new_external_id do
      if old_external_id, do: :ets.delete(@external_id_index, old_external_id)
      if new_external_id, do: :ets.insert(@external_id_index, {new_external_id, user_id})
    end

    :ok
  end

  defp apply_sorting(users, []), do: users

  defp apply_sorting(users, sort_opts) do
    {sort_field, sort_direction} = Keyword.get(sort_opts, :sort_by, {"userName", :asc})

    Enum.sort_by(
      users,
      fn user ->
        get_in(user, [sort_field]) || ""
      end,
      sort_direction
    )
  end

  defp apply_pagination(users, []), do: users

  defp apply_pagination(users, pagination_opts) do
    start_index = Keyword.get(pagination_opts, :start_index, 1)
    count = Keyword.get(pagination_opts, :count, 20)

    users
    |> Enum.drop(start_index - 1)
    |> Enum.take(count)
  end

  # Group-specific helper functions
  defp validate_group_unique_constraints(group_id, display_name, external_id) do
    cond do
      group_exists?(group_id) ->
        {:error, :group_id_taken}

      display_name && match?({:ok, _}, get_group_by_display_name(display_name)) ->
        {:error, :display_name_taken}

      external_id && match?({:ok, _}, get_group_by_external_id(external_id)) ->
        {:error, :external_id_taken}

      true ->
        :ok
    end
  end

  defp validate_group_update_constraints(
         _group_id,
         new_display_name,
         new_external_id,
         old_display_name,
         old_external_id
       ) do
    cond do
      new_display_name != old_display_name && new_display_name &&
          match?({:ok, _}, get_group_by_display_name(new_display_name)) ->
        {:error, :display_name_taken}

      new_external_id != old_external_id && new_external_id &&
          match?({:ok, _}, get_group_by_external_id(new_external_id)) ->
        {:error, :external_id_taken}

      true ->
        :ok
    end
  end

  defp store_group(group_id, group_data, display_name, external_id) do
    :ets.insert(@groups_table_name, {group_id, group_data})
    if display_name, do: :ets.insert(@groups_display_name_index, {display_name, group_id})
    if external_id, do: :ets.insert(@groups_external_id_index, {external_id, group_id})
    :ok
  end

  defp update_group_indexes(
         group_id,
         new_display_name,
         new_external_id,
         old_display_name,
         old_external_id
       ) do
    if old_display_name != new_display_name do
      if old_display_name, do: :ets.delete(@groups_display_name_index, old_display_name)

      if new_display_name,
        do: :ets.insert(@groups_display_name_index, {new_display_name, group_id})
    end

    if old_external_id != new_external_id do
      if old_external_id, do: :ets.delete(@groups_external_id_index, old_external_id)
      if new_external_id, do: :ets.insert(@groups_external_id_index, {new_external_id, group_id})
    end

    :ok
  end
end
