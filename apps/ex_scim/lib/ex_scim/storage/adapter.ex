defmodule ExScim.Storage.Adapter do
  @moduledoc "Storage adapter behaviour."

  @type user_id :: binary()
  @type group_id :: binary()
  @type domain_user :: struct()
  @type domain_group :: struct()
  @type filter_ast :: term() | nil
  @type sort_opts :: keyword()
  @type pagination_opts :: keyword()
  @type scope :: ExScim.Scope.t() | nil

  @callback get_user(user_id(), scope()) :: {:ok, domain_user()} | {:error, :not_found}
  @callback list_users(filter_ast(), sort_opts(), pagination_opts(), scope()) ::
              {:ok, [domain_user()], non_neg_integer()}

  @callback create_user(domain_user(), scope()) :: {:ok, domain_user()} | {:error, term()}
  @callback update_user(user_id(), domain_user(), scope()) :: {:ok, domain_user()} | {:error, term()}
  @callback replace_user(user_id(), domain_user(), scope()) :: {:ok, domain_user()} | {:error, term()}
  @callback delete_user(user_id(), scope()) :: :ok | {:error, term()}

  @callback user_exists?(user_id(), scope()) :: boolean()

  @callback get_group(group_id(), scope()) :: {:ok, domain_group()} | {:error, :not_found}
  @callback list_groups(filter_ast(), sort_opts(), pagination_opts(), scope()) ::
              {:ok, [domain_group()], non_neg_integer()}

  @callback create_group(domain_group(), scope()) :: {:ok, domain_group()} | {:error, term()}
  @callback update_group(group_id(), domain_group(), scope()) :: {:ok, domain_group()} | {:error, term()}
  @callback replace_group(group_id(), domain_group(), scope()) :: {:ok, domain_group()} | {:error, term()}
  @callback delete_group(group_id(), scope()) :: :ok | {:error, term()}

  @callback group_exists?(group_id(), scope()) :: boolean()
end
