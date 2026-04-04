# ExScimPhoenix

Phoenix integration for [ExScim](https://github.com/ExScim/ex_scim). Provides a full set of SCIM 2.0 HTTP endpoints as Phoenix controllers, along with authentication, content-type negotiation, and tenant resolution plugs.

## Installation

Add `ex_scim_phoenix` to your dependencies:

```elixir
def deps do
  [
    {:ex_scim_phoenix, "~> 0.1"}
  ]
end
```

## Usage

Add SCIM routes to your Phoenix router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :scim_api do
    plug :accepts, ["json", "scim+json"]
    plug ExScimPhoenix.Plugs.ScimContentType
    plug ExScimPhoenix.Plugs.ScimAuth
  end

  scope "/scim/v2" do
    pipe_through :scim_api
    use ExScimPhoenix.Router
  end
end
```

## Available Plugs

- `ExScimPhoenix.Plugs.ScimAuth` - Authenticates requests via Bearer token or HTTP Basic
- `ExScimPhoenix.Plugs.RequireScopes` - Enforces authorization scopes per action
- `ExScimPhoenix.Plugs.ScimContentType` - Sets `application/scim+json` response content type
- `ExScimPhoenix.Plugs.ScimTenant` - Resolves tenant context from the request
- `ExScimPhoenix.Plugs.RequestLogger` - Logs SCIM requests for debugging

## Controllers

The router macro registers these controllers automatically:

- `UserController` - `/Users` CRUD operations
- `GroupController` - `/Groups` CRUD operations
- `MeController` - `/Me` authenticated user self-management
- `SearchController` - `/.search` POST-based queries
- `BulkController` - `/Bulk` batch operations
- `SchemaController` - `/Schemas` discovery
- `ResourceTypeController` - `/ResourceTypes` discovery
- `ServiceProviderConfigController` - `/ServiceProviderConfig` capabilities

## Authorization Scopes

Scope strings are populated by your `AuthProvider.Adapter` and enforced per action:

| Scope | Actions |
|---|---|
| `scim:read` | GET list, show, search on Users/Groups and all discovery endpoints |
| `scim:create` | POST `/Users`, POST `/Groups`, POST operations in `/Bulk` |
| `scim:update` | PUT and PATCH on `/Users`, `/Groups`; PUT/PATCH operations in `/Bulk` |
| `scim:delete` | DELETE on `/Users`, `/Groups`; DELETE operations in `/Bulk` |
| `scim:me:read` | GET `/Me` |
| `scim:me:create` | POST `/Me` |
| `scim:me:update` | PUT `/Me`, PATCH `/Me` |
| `scim:me:delete` | DELETE `/Me` |

For `/Bulk`, scope is checked per operation - a caller with `scim:create` only may include POST operations; PUT/PATCH/DELETE operations in the same request will each return a `403` operation result.

See the [configuration guide](https://hexdocs.pm/ex_scim/configuration.html) for example scope lists.
