# ExScim

Core SCIM v2.0 library.

## Configuration

```elixir
config :ex_scim,
  user_resource_mapper: YourApp.UserMapper,
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: YourApp.Repo,
  storage_schema: YourApp.Accounts.User
```

