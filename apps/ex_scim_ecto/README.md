# ExScimEcto

Ecto-based storage adapter for [ExScim](https://github.com/ExScim/ex_scim). Provides persistent storage for SCIM Users and Groups backed by any Ecto-compatible database.

## Installation

Add `ex_scim_ecto` to your dependencies:

```elixir
def deps do
  [
    {:ex_scim_ecto, "~> 0.5"}
  ]
end
```

## Configuration

### Basic setup

```elixir
config :ex_scim,
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: MyApp.Repo,
  user_model: MyApp.Accounts.User,
  group_model: MyApp.Groups.Group
```

### Preloading associations

```elixir
config :ex_scim,
  storage_repo: MyApp.Repo,
  user_model: {MyApp.Accounts.User, preload: [:roles, :organizations]},
  group_model: {MyApp.Groups.Group, preload: [:owner]}
```

### Custom lookup key

By default, resources are looked up by `:id`. To use a different column:

```elixir
config :ex_scim,
  user_model: {MyApp.Accounts.User, lookup_key: :resource_id},
  group_model: {MyApp.Groups.Group, lookup_key: :uuid}
```

### Filter mapping

Map SCIM complex attribute paths to database columns:

```elixir
config :ex_scim,
  user_model: {MyApp.Accounts.User,
    filter_mapping: %{
      "emails.value" => :email,
      "name.givenName" => :given_name
    }}
```

For association-based filtering (e.g. filtering on a `has_many` relation):

```elixir
config :ex_scim,
  user_model: {MyApp.Accounts.User,
    preload: [:user_emails],
    filter_mapping: %{
      "emails.value" => {:assoc, :user_emails, :value},
      "emails.type" => {:assoc, :user_emails, :type}
    }}
```

### Group memberships

Store `Group.members`, including nested groups, in one table. ExScim then
derives `User.groups` with direct and indirect memberships:

```elixir
config :ex_scim,
  membership_model: MyApp.Groups.Membership
```

```elixir
create table(:group_memberships) do
  add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all)
  add :member_id, :binary_id, null: false
  add :member_type, :string, null: false
end

create unique_index(:group_memberships, [:group_id, :member_type, :member_id])
create index(:group_memberships, [:member_type, :member_id])
```

`:member_type` holds `"User"` or `"Group"`. Other column names can be set with
`{MyApp.Groups.Membership, group_key: ..., member_key: ..., type_key: ...}`.
The group mapper doesn't handle `members` then.

### Multi-tenant scoping

Scope all queries by a tenant discriminator column:

```elixir
config :ex_scim,
  user_model: {MyApp.Accounts.User, tenant_key: :organization_id},
  group_model: {MyApp.Groups.Group, tenant_key: :organization_id}
```

### Field mapping

Map domain fields to database columns with value transformation:

```elixir
config :ex_scim,
  user_model: {MyApp.Accounts.User,
    field_mapping: %{
      active: {:status,
        fn true -> "active"; false -> "inactive" end,
        fn "active" -> true; _ -> false end}
    }}
```

Each entry is `domain_field => {db_field, to_storage_fn, from_storage_fn}`.

## Ecto schema requirements

Your Ecto schema must define a `changeset/2` function that the adapter will call for inserts and updates:

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  schema "users" do
    field :user_name, :string
    field :display_name, :string
    # ...
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:user_name, :display_name])
    |> validate_required([:user_name])
  end
end
```
