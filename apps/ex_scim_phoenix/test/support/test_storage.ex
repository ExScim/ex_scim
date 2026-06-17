defmodule ExScimPhoenix.Test.TestStorage do
  @moduledoc """
  Agent-backed storage adapter for controller pipeline tests.

  Mirrors the adapter used in `ExScim.Operations.{Users,Groups}Test`: it stores
  the atom-keyed domain maps produced by the Operations layer, which the real
  `EtsStorage` adapter does not round-trip (string vs atom keys). Supports the
  full `ExScim.Storage.Adapter` behaviour for both users and groups, including
  filter and pagination so list endpoints behave realistically.
  """

  @behaviour ExScim.Storage.Adapter

  def start_link do
    case Agent.start_link(fn -> %{users: %{}, groups: %{}} end, name: __MODULE__) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # Reset to a clean slate in case a prior on_exit stop hasn't run yet.
        Agent.update(__MODULE__, fn _ -> %{users: %{}, groups: %{}} end)
        {:ok, pid}
    end
  end

  def stop do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      pid -> Agent.stop(pid)
    end
  end

  @impl true
  def get_user(user_id, _scope \\ nil) do
    case Agent.get(__MODULE__, &get_in(&1, [:users, user_id])) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @impl true
  def list_users(filter_ast \\ nil, _sort_opts \\ [], pagination_opts \\ [], scope \\ nil) do
    Agent.get(__MODULE__, &Map.values(&1.users))
    |> paginate(filter_ast, pagination_opts, ExScim.Users.Mapper.DefaultMapper, scope)
  end

  @impl true
  def create_user(user_data, _scope \\ nil) do
    user_id = Map.get(user_data, :id) || Map.get(user_data, "id")
    user_name = Map.get(user_data, :user_name) || Map.get(user_data, "userName")

    if user_name && username_taken?(user_name) do
      {:error, :conflict}
    else
      Agent.update(__MODULE__, &put_in(&1, [:users, user_id], user_data))
      {:ok, user_data}
    end
  end

  defp username_taken?(user_name) do
    Agent.get(__MODULE__, &Map.values(&1.users))
    |> Enum.any?(&(Map.get(&1, :user_name) == user_name))
  end

  @impl true
  def update_user(user_id, user_data, _scope \\ nil) do
    with {:ok, _} <- get_user(user_id) do
      Agent.update(__MODULE__, &put_in(&1, [:users, user_id], user_data))
      {:ok, user_data}
    end
  end

  @impl true
  def replace_user(user_id, user_data, _scope \\ nil) do
    with {:ok, _} <- get_user(user_id) do
      Agent.update(__MODULE__, &put_in(&1, [:users, user_id], user_data))
      {:ok, user_data}
    end
  end

  @impl true
  def delete_user(user_id, _scope \\ nil) do
    with {:ok, _} <- get_user(user_id) do
      Agent.update(__MODULE__, &update_in(&1, [:users], fn m -> Map.delete(m, user_id) end))
      :ok
    end
  end

  @impl true
  def user_exists?(user_id, _scope \\ nil) do
    match?({:ok, _}, get_user(user_id))
  end

  @impl true
  def get_group(group_id, _scope \\ nil) do
    case Agent.get(__MODULE__, &get_in(&1, [:groups, group_id])) do
      nil -> {:error, :not_found}
      group -> {:ok, group}
    end
  end

  @impl true
  def list_groups(filter_ast \\ nil, _sort_opts \\ [], pagination_opts \\ [], scope \\ nil) do
    Agent.get(__MODULE__, &Map.values(&1.groups))
    |> paginate(filter_ast, pagination_opts, ExScim.Groups.Mapper.DefaultMapper, scope)
  end

  @impl true
  def create_group(group_data, _scope \\ nil) do
    group_id = Map.get(group_data, :id) || Map.get(group_data, "id")
    display_name = Map.get(group_data, :display_name) || Map.get(group_data, "displayName")

    if display_name && display_name_taken?(display_name) do
      {:error, :conflict}
    else
      Agent.update(__MODULE__, &put_in(&1, [:groups, group_id], group_data))
      {:ok, group_data}
    end
  end

  defp display_name_taken?(display_name) do
    Agent.get(__MODULE__, &Map.values(&1.groups))
    |> Enum.any?(&(Map.get(&1, :display_name) == display_name))
  end

  @impl true
  def update_group(group_id, group_data, _scope \\ nil) do
    with {:ok, _} <- get_group(group_id) do
      Agent.update(__MODULE__, &put_in(&1, [:groups, group_id], group_data))
      {:ok, group_data}
    end
  end

  @impl true
  def replace_group(group_id, group_data, _scope \\ nil) do
    with {:ok, _} <- get_group(group_id) do
      Agent.update(__MODULE__, &put_in(&1, [:groups, group_id], group_data))
      {:ok, group_data}
    end
  end

  @impl true
  def delete_group(group_id, _scope \\ nil) do
    with {:ok, _} <- get_group(group_id) do
      Agent.update(__MODULE__, &update_in(&1, [:groups], fn m -> Map.delete(m, group_id) end))
      :ok
    end
  end

  @impl true
  def group_exists?(group_id, _scope \\ nil) do
    match?({:ok, _}, get_group(group_id))
  end

  # Filtering is expressed in SCIM attribute names (e.g. "userName"), but stored
  # records are atom-keyed domain maps (e.g. :user_name). Map each record to its
  # SCIM form before evaluating the filter, then keep the matching domain records.
  defp paginate(records, filter_ast, pagination_opts, mapper, scope) do
    filtered =
      case filter_ast do
        nil ->
          records

        ast ->
          Enum.filter(records, fn record ->
            {:ok, scim} = mapper.to_scim(record, scope, [])
            ExScim.QueryFilter.EtsQueryFilter.apply_filter([scim], ast) != []
          end)
      end

    total = length(filtered)
    start_index = Keyword.get(pagination_opts, :start_index, 1)
    count = Keyword.get(pagination_opts, :count, 20)

    paginated =
      filtered
      |> Enum.drop(start_index - 1)
      |> Enum.take(count)

    {:ok, paginated, total}
  end
end
