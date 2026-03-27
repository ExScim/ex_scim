# ExScim

[![CI](https://github.com/ExScim/ex_scim_umbrella/actions/workflows/ci.yml/badge.svg)](https://github.com/ExScim/ex_scim_umbrella/actions/workflows/ci.yml)

SCIM 2.0 implementation for Elixir. Adapter-based and modular - bring your own storage, authentication, and resource mapping. Built on [RFC 7643](https://www.rfc-editor.org/rfc/rfc7643), [RFC 7644](https://www.rfc-editor.org/rfc/rfc7644), and [RFC 6902](https://www.rfc-editor.org/rfc/rfc6902).

## Packages

| Package | Description |
|---------|-------------|
| [`ex_scim`](https://hex.pm/packages/ex_scim) | Core SCIM logic, operations, filter/path parsers |
| [`ex_scim_ecto`](https://hex.pm/packages/ex_scim_ecto) | Ecto storage adapter (PostgreSQL, MySQL, SQLite) |
| [`ex_scim_phoenix`](https://hex.pm/packages/ex_scim_phoenix) | Phoenix controllers, router, and plugs |
| [`ex_scim_client`](https://hex.pm/packages/ex_scim_client) | HTTP client for consuming SCIM APIs |

## Installation

Add the packages you need to `mix.exs`:

```elixir
{:ex_scim, "~> 0.1.2"},
{:ex_scim_ecto, "~> 0.1.2"},        # optional: Ecto storage
{:ex_scim_phoenix, "~> 0.1.2"},     # optional: Phoenix endpoints
{:ex_scim_client, "~> 0.1.2"}       # optional: HTTP client
```

## Quick Start

Configure ExScim and mount the SCIM routes:

```elixir
# config/config.exs
config :ex_scim,
  base_url: "https://your-domain.com",
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: MyApp.Repo,
  user_model: MyApp.Accounts.User,
  group_model: MyApp.Accounts.Group,
  auth_provider_adapter: MyApp.Scim.AuthProvider
```

```elixir
# lib/my_app_web/router.ex
pipeline :scim_api do
  plug :accepts, ["json", "scim+json"]
  plug ExScimPhoenix.Plugs.ScimContentType
  plug ExScimPhoenix.Plugs.ScimAuth
end

scope "/scim/v2" do
  pipe_through :scim_api
  use ExScimPhoenix.Router
end
```

All SCIM endpoints are now available under `/scim/v2`.

## Features

- User and Group CRUD with search, filtering, sorting, and pagination
- Bulk operations
- JSON Patch (RFC 6902)
- Discovery endpoints (ServiceProviderConfig, ResourceTypes, Schemas)
- Multi-tenancy support with pluggable tenant resolution
- Replaceable adapters for storage, resource mapping, authentication, and validation
- RFC-compliant error responses

## Documentation

Full configuration reference, multi-tenancy guide, custom adapter examples, and endpoint listing are available on [HexDocs](https://hexdocs.pm/ex_scim).

## Example

The [`examples/provider`](./examples/provider) app demonstrates a complete SCIM server with Phoenix, Ecto, and SQLite:

```bash
cd examples/provider
mix deps.get && mix ecto.setup
mix phx.server
```

## Development

Run all tests from the umbrella root:

```bash
mix test
```

Or test a single package:

```bash
cd apps/ex_scim && mix test
```

## License

MIT
