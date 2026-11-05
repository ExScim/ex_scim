defmodule ExScim.Storage.Adapter do
  @moduledoc """
  Behaviour defining the contract for all storage backends.

  Implementations must handle CRUD operations for both Users and Groups.
  Each callback receives an optional `scope` for multi-tenant isolation.

  See `ExScim.Storage.EtsStorage` for a reference implementation, or
  `ExScimEcto.StorageAdapter` for a production-ready Ecto-based backend.

  ## Configuration

      config :ex_scim, storage_strategy: MyApp.Storage
  """

  @typedoc "Unique identifier for a user resource."
  @type user_id :: binary()

  @typedoc "Unique identifier for a group resource."
  @type group_id :: binary()

  @typedoc "A domain-level user struct or map as stored by the backend."
  @type domain_user :: struct()

  @typedoc "A domain-level group struct or map as stored by the backend."
  @type domain_group :: struct()

  @typedoc """
  Parsed SCIM filter AST, or `nil` for no filter.

  The AST is a nested tuple structure, e.g. `{:eq, "userName", "alice"}`
  or `{:and, {:eq, "active", "true"}, {:co, "userName", "john"}}`.
  """
  @type filter_ast :: term() | nil

  @typedoc "Sort options, e.g. `[sort_by: {\"userName\", :asc}]`."
  @type sort_opts :: keyword()

  @typedoc "Pagination options, e.g. `[start_index: 1, count: 20]`."
  @type pagination_opts :: keyword()

  @typedoc "Caller scope for multi-tenant isolation, or `nil`."
  @type scope :: ExScim.Scope.t() | nil

  @doc "Retrieves a single user by ID."
  @callback get_user(user_id(), scope()) :: {:ok, domain_user()} | {:error, :not_found}

  @doc "Lists users matching a filter with sorting and pagination. Returns `{:ok, users, total_count}`."
  @callback list_users(filter_ast(), sort_opts(), pagination_opts(), scope()) ::
              {:ok, [domain_user()], non_neg_integer()}

  @doc "Persists a new user."
  @callback create_user(domain_user(), scope()) :: {:ok, domain_user()} | {:error, term()}

  @doc "Partially updates an existing user (PATCH)."
  @callback update_user(user_id(), domain_user(), scope()) ::
              {:ok, domain_user()} | {:error, term()}

  @doc "Fully replaces an existing user (PUT)."
  @callback replace_user(user_id(), domain_user(), scope()) ::
              {:ok, domain_user()} | {:error, term()}

  @doc "Deletes a user by ID."
  @callback delete_user(user_id(), scope()) :: :ok | {:error, term()}

  @doc "Returns `true` if a user with the given ID exists."
  @callback user_exists?(user_id(), scope()) :: boolean()

  @doc "Retrieves a single group by ID."
  @callback get_group(group_id(), scope()) :: {:ok, domain_group()} | {:error, :not_found}

  @doc "Lists groups matching a filter with sorting and pagination. Returns `{:ok, groups, total_count}`."
  @callback list_groups(filter_ast(), sort_opts(), pagination_opts(), scope()) ::
              {:ok, [domain_group()], non_neg_integer()}

  @doc "Persists a new group."
  @callback create_group(domain_group(), scope()) :: {:ok, domain_group()} | {:error, term()}

  @doc "Partially updates an existing group (PATCH)."
  @callback update_group(group_id(), domain_group(), scope()) ::
              {:ok, domain_group()} | {:error, term()}

  @doc "Fully replaces an existing group (PUT)."
  @callback replace_group(group_id(), domain_group(), scope()) ::
              {:ok, domain_group()} | {:error, term()}

  @doc "Deletes a group by ID."
  @callback delete_group(group_id(), scope()) :: :ok | {:error, term()}

  @doc "Returns `true` if a group with the given ID exists."
  @callback group_exists?(group_id(), scope()) :: boolean()

  @doc """
  Runs `fun` in a transaction, rolling back on `{:error, term()}` or an exception.

  Optional. Without it, `fun` runs without a transaction.
  """
  @callback transaction(fun :: (-> result)) :: result
            when result: :ok | {:ok, term()} | {:error, term()}

  @typedoc "Resource type of a group member."
  @type member_type :: :user | :group

  @typedoc "A group member as stored: its type and SCIM `id`."
  @type member_ref :: {member_type(), binary()}

  @typedoc "A group member as loaded: its type and stored record."
  @type member :: {:user, domain_user()} | {:group, domain_group()}

  @doc "Lists the direct members of a group."
  @callback list_members(group_id(), scope()) :: {:ok, [member()]} | {:error, term()}

  @doc "Sets the direct members of a group to `members`."
  @callback replace_members(group_id(), members :: [member_ref()], scope()) ::
              :ok | {:error, term()}

  @doc "Lists the groups that have the given user or group as a direct member."
  @callback list_groups_for_member(member_ref(), scope()) ::
              {:ok, [domain_group()]} | {:error, term()}

  @doc """
  Returns whether this adapter stores group memberships.

  Optional. Defaults to `true` when the membership callbacks are implemented.
  """
  @callback memberships?() :: boolean()

  @optional_callbacks transaction: 1,
                      list_members: 2,
                      replace_members: 3,
                      list_groups_for_member: 2,
                      memberships?: 0
end
