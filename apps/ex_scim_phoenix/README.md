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
