defmodule ExScim.Storage.Adapter do
  @moduledoc "Storage adapter behaviour."

  @type user_id :: binary()
  @type group_id :: binary()
  @type domain_user :: struct()
  @type domain_group :: struct()
  @type filter_ast :: term() | nil
  @type sort_opts :: keyword()
  @type pagination_opts :: keyword()
  @callback get_user(user_id()) :: {:ok, domain_user()} | {:error, :not_found}
  @callback get_user_by_username(binary()) :: {:ok, domain_user()} | {:error, :not_found}
  @callback get_user_by_external_id(binary()) :: {:ok, domain_user()} | {:error, :not_found}
  @callback list_users(filter_ast(), sort_opts(), pagination_opts()) ::
              {:ok, [domain_user()], non_neg_integer()}

  @callback create_user(domain_user()) :: {:ok, domain_user()} | {:error, term()}
  @callback update_user(user_id(), domain_user()) :: {:ok, domain_user()} | {:error, term()}
  @callback replace_user(user_id(), domain_user()) :: {:ok, domain_user()} | {:error, term()}
  @callback delete_user(user_id()) :: :ok | {:error, term()}

  @callback user_exists?(user_id()) :: boolean()

  @callback get_group(group_id()) :: {:ok, domain_group()} | {:error, :not_found}
  @callback get_group_by_display_name(binary()) :: {:ok, domain_group()} | {:error, :not_found}
  @callback get_group_by_external_id(binary()) :: {:ok, domain_group()} | {:error, :not_found}
  @callback list_groups(filter_ast(), sort_opts(), pagination_opts()) ::
              {:ok, [domain_group()], non_neg_integer()}

  @callback create_group(domain_group()) :: {:ok, domain_group()} | {:error, term()}
  @callback update_group(group_id(), domain_group()) :: {:ok, domain_group()} | {:error, term()}
  @callback replace_group(group_id(), domain_group()) :: {:ok, domain_group()} | {:error, term()}
  @callback delete_group(group_id()) :: :ok | {:error, term()}

  @callback group_exists?(group_id()) :: boolean()
end
