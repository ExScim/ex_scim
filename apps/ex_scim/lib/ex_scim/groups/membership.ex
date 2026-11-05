defmodule ExScim.Groups.Membership do
  @moduledoc false

  alias ExScim.Config
  alias ExScim.Resources.Resource
  alias ExScim.Storage

  @spec enabled?() :: boolean()
  def enabled?, do: Storage.memberships?()

  @spec split(map()) :: {list() | :skip, map()}
  def split(scim_group) do
    if enabled?() do
      {members, rest} = pop_attribute(scim_group, "members")
      {members || [], rest}
    else
      {:skip, scim_group}
    end
  end

  @spec split(map(), map()) :: {list() | :skip, map()}
  def split(scim_group, current) do
    case split(scim_group) do
      {:skip, rest} ->
        {:skip, rest}

      {members, rest} ->
        if members == (current["members"] || []), do: {:skip, rest}, else: {members, rest}
    end
  end

  @spec replace(binary(), list() | :skip, ExScim.Scope.t() | nil) :: :ok | {:error, term()}
  def replace(_group_id, :skip, _scope), do: :ok

  def replace(group_id, members, scope) when is_list(members) do
    with {:ok, refs} <- map_while(members, &to_ref(&1, scope)),
         refs = Enum.uniq(refs),
         :ok <- check_cycles(group_id, refs, scope) do
      Storage.replace_members(group_id, refs, scope)
    end
  end

  def replace(_group_id, _members, _scope), do: invalid("must be an array")

  @spec put_members(map(), binary() | nil, ExScim.Scope.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def put_members(scim_group, nil, _scope), do: {:ok, scim_group}

  def put_members(scim_group, group_id, scope) do
    if enabled?() do
      with {:ok, members} <- Storage.list_members(group_id, scope),
           {:ok, entries} <- map_while(members, &member_entry(&1, scope)) do
        {:ok, Map.put(scim_group, "members", entries)}
      end
    else
      {:ok, scim_group}
    end
  end

  @spec put_groups(map(), binary() | nil, ExScim.Scope.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def put_groups(scim_user, nil, _scope), do: {:ok, scim_user}

  def put_groups(scim_user, user_id, scope) do
    if enabled?() do
      with {:ok, direct} <- Storage.list_groups_for_member({:user, user_id}, scope),
           {:ok, indirect} <- ancestors(direct, MapSet.new(ids(direct)), scope),
           {:ok, direct} <- map_while(direct, &group_entry(&1, "direct", scope)),
           {:ok, indirect} <- map_while(indirect, &group_entry(&1, "indirect", scope)) do
        {:ok, Map.put(scim_user, "groups", direct ++ indirect)}
      end
    else
      {:ok, scim_user}
    end
  end

  @spec remove_member(ExScim.Storage.Adapter.member_ref(), ExScim.Scope.t() | nil) ::
          :ok | {:error, term()}
  def remove_member(member_ref, scope) do
    if enabled?() do
      with {:ok, groups} <- Storage.list_groups_for_member(member_ref, scope) do
        each_while(groups, &remove_from_group(Resource.get_id(&1), member_ref, scope))
      end
    else
      :ok
    end
  end

  @spec remove_group(binary(), ExScim.Scope.t() | nil) :: :ok | {:error, term()}
  def remove_group(group_id, scope) do
    if enabled?() do
      with :ok <- Storage.replace_members(group_id, [], scope) do
        remove_member({:group, group_id}, scope)
      end
    else
      :ok
    end
  end

  @spec drop_groups(map()) :: map()
  def drop_groups(scim_user) do
    {_groups, rest} = pop_attribute(scim_user, "groups")
    rest
  end

  defp remove_from_group(group_id, member_ref, scope) do
    with {:ok, members} <- Storage.list_members(group_id, scope) do
      refs =
        for {type, record} <- members,
            ref = {type, Resource.get_id(record)},
            ref != member_ref,
            do: ref

      Storage.replace_members(group_id, refs, scope)
    end
  end

  defp to_ref(%{"value" => id} = member, scope) when is_binary(id) do
    case member_type(member["type"]) do
      :user ->
        if Storage.user_exists?(id, scope),
          do: {:ok, {:user, id}},
          else: invalid("User #{id} not found")

      :group ->
        if Storage.group_exists?(id, scope),
          do: {:ok, {:group, id}},
          else: invalid("Group #{id} not found")

      nil ->
        cond do
          Storage.user_exists?(id, scope) -> {:ok, {:user, id}}
          Storage.group_exists?(id, scope) -> {:ok, {:group, id}}
          true -> invalid("#{id} not found")
        end

      :unknown ->
        invalid("type must be \"User\" or \"Group\"")
    end
  end

  defp to_ref(_member, _scope), do: invalid("every member needs a value")

  defp member_type(nil), do: nil

  defp member_type(type) when is_binary(type) do
    case String.downcase(type) do
      "user" -> :user
      "group" -> :group
      _ -> :unknown
    end
  end

  defp member_type(_type), do: :unknown

  defp check_cycles(group_id, refs, scope) do
    member_groups = for {:group, id} <- refs, do: id

    cond do
      group_id in member_groups ->
        invalid("a group can't be a member of itself")

      member_groups == [] ->
        :ok

      true ->
        with {:ok, parents} <- Storage.list_groups_for_member({:group, group_id}, scope),
             {:ok, ancestors} <- ancestors(parents, MapSet.new([group_id | ids(parents)]), scope) do
          contains = MapSet.new(ids(parents) ++ ids(ancestors))

          case Enum.find(member_groups, &MapSet.member?(contains, &1)) do
            nil -> :ok
            id -> invalid("Group #{id} already contains this group")
          end
        end
    end
  end

  defp ancestors(groups, seen, scope), do: walk(groups, seen, [], scope)

  defp walk([], _seen, acc, _scope), do: {:ok, Enum.reverse(acc)}

  defp walk([group | rest], seen, acc, scope) do
    with {:ok, parents} <- Storage.list_groups_for_member({:group, Resource.get_id(group)}, scope) do
      new =
        parents
        |> Enum.reject(&MapSet.member?(seen, Resource.get_id(&1)))
        |> Enum.uniq_by(&Resource.get_id/1)

      seen = Enum.reduce(new, seen, &MapSet.put(&2, Resource.get_id(&1)))
      walk(rest ++ new, seen, Enum.reverse(new, acc), scope)
    end
  end

  defp member_entry({:user, user}, scope) do
    with {:ok, scim_user} <- ExScim.Users.Mapper.to_scim(user, scope) do
      display = scim_user["displayName"] || scim_user["userName"]
      {:ok, entry(Resource.get_id(user), "Users", "User", display, scope)}
    end
  end

  defp member_entry({:group, group}, scope) do
    with {:ok, scim_group} <- ExScim.Groups.Mapper.to_scim(group, scope) do
      {:ok, entry(Resource.get_id(group), "Groups", "Group", scim_group["displayName"], scope)}
    end
  end

  defp group_entry(group, type, scope) do
    with {:ok, scim_group} <- ExScim.Groups.Mapper.to_scim(group, scope) do
      {:ok, entry(Resource.get_id(group), "Groups", type, scim_group["displayName"], scope)}
    end
  end

  defp entry(id, endpoint, type, display, scope) do
    %{
      "value" => id,
      "$ref" => Config.resource_url(endpoint, id, scope),
      "display" => display,
      "type" => type
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp ids(groups), do: Enum.map(groups, &Resource.get_id/1)

  defp pop_attribute(scim, name) do
    case Enum.find(Map.keys(scim), &(is_binary(&1) and String.downcase(&1) == name)) do
      nil -> {nil, scim}
      key -> Map.pop(scim, key)
    end
  end

  defp map_while(list, fun) do
    list
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp each_while(list, fun) do
    Enum.reduce_while(list, :ok, fn item, :ok ->
      case fun.(item) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp invalid(message), do: {:error, [{"members", message}]}
end
