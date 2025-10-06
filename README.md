# ExScim

[![ExScim Project](https://github.com/wheredoipressnow/ex_scim/actions/workflows/multi-project-elixir.yml/badge.svg)](https://github.com/wheredoipressnow/ex_scim/actions/workflows/multi-project-elixir.yml)

SCIM 2.0 implementation in Elixir.  
Based on the official specifications:  
- [RFC 7643: SCIM Core Schema](https://www.rfc-editor.org/rfc/rfc7643)  
- [RFC 7644: SCIM Protocol](https://www.rfc-editor.org/rfc/rfc7644)  
- [RFC 6902: JSON Patch](https://www.rfc-editor.org/rfc/rfc6902)  

The system is modular and adapter-based, so storage, mapping, authentication, and validation can be customized.

---

## Quickstart

Add the dependencies you need to `mix.exs`:

```elixir
{:ex_scim, path: "ex_scim"}
{:ex_scim_ecto, path: "ex_scim_ecto"}       # optional: Ecto storage
{:ex_scim_phoenix, path: "ex_scim_phoenix"} # optional: Phoenix endpoints
{:ex_scim_client, path: "ex_scim_client"}   # optional: HTTP client
````

Run the example provider app to see a working SCIM setup:

```bash
cd examples/provider
mix ecto.setup
mix phx.server
```

Endpoints will be available under `/scim/v2`.

---

## Architecture Overview

ExScim is split into four packages:

```
ex_scim/          # Core SCIM logic and operations
ex_scim_ecto/     # Database persistence via Ecto
ex_scim_phoenix/  # HTTP endpoints and Phoenix integration
ex_scim_client/   # HTTP client for consuming SCIM APIs
```

### Core Design

* **Adapters**: All major components are replaceable via behaviours:

  * [`ExScim.Storage.Adapter`](./ex_scim/lib/ex_scim/storage/adapter.ex) – data persistence
  * [`ExScim.Users.Mapper.Adapter`](./ex_scim/lib/ex_scim/users/mapper/adapter.ex) – domain ↔ SCIM mapping
  * [`ExScim.Auth.AuthProvider.Adapter`](./ex_scim/lib/ex_scim/auth/auth_provider/adapter.ex) – authentication / authorization
  * [`ExScim.Schema.Validator.Adapter`](./ex_scim/lib/ex_scim/schema/validator/adapter.ex) – schema validation
  * [`ExScim.QueryFilter.Adapter`](./ex_scim/lib/ex_scim/query_filter/adapter.ex) – SCIM filter parsing ([RFC 7644 §3.4.2.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2.2))

* **Operations Layer**: Encapsulates business logic

  * `ExScim.Operations.Users` – User CRUD and search
  * `ExScim.Operations.Groups` – Group CRUD and membership
  * `ExScim.Operations.Bulk` – Bulk operation processing ([RFC 7644 §3.7](https://www.rfc-editor.org/rfc/rfc7644#section-3.7))

* **Resource Transformation**: Clear separation between

  * Application domain structs (e.g. `%User{}`)
  * SCIM JSON representation ([RFC 7643](https://www.rfc-editor.org/rfc/rfc7643))
  * Mapping handled through adapters

---

## Package Details

### ex\_scim – Core Library

* Operations for Users, Groups, and Bulk
* Unified storage interface
* SCIM filter/path parsers
* Resource handling (IDs, metadata)
* Schema validation and repository ([RFC 7643 §7](https://www.rfc-editor.org/rfc/rfc7643#section-7))
* RFC 7644-compliant error responses ([RFC 7644 §3.12](https://www.rfc-editor.org/rfc/rfc7644#section-3.12))
* Default user/group mappers

### ex\_scim\_ecto – Database Integration

* Ecto `StorageAdapter` implementation
* Converts SCIM filters to Ecto queries
* Works with PostgreSQL, MySQL, SQLite, etc.

### ex\_scim\_phoenix – HTTP API

* Controllers for Users, Groups, Me, Search, Bulk, Discovery
* Complete SCIM 2.0 router ([RFC 7644 §3](https://www.rfc-editor.org/rfc/rfc7644#section-3))
* Plugs for auth, content-type handling, logging
* HTTP error ↔ SCIM error mapping

### ex\_scim\_client – HTTP Client

* HTTP client for consuming SCIM APIs
* User and Group resource operations
* Filtering, sorting, pagination support
* Bulk operations and schema discovery
* Request builder with authentication

---

## Configuration Example

```elixir
config :ex_scim,
  base_url: "https://your-domain.com",

  # Storage
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: MyApp.Repo,
  user_model: MyApp.Accounts.User,
  group_model: MyApp.Accounts.Group,

  # Resource mapping
  user_resource_mapper: MyApp.Scim.UserMapper,
  group_resource_mapper: MyApp.Scim.GroupMapper,

  # Authentication
  auth_provider_adapter: MyApp.Scim.AuthProvider,

  # Schema validation
  scim_validator: ExScim.Schema.Validator.DefaultValidator,
  scim_schema_repository: ExScim.Schema.Repository.DefaultRepository,

  # Bulk operations
  bulk_supported: true,
  bulk_max_operations: 1000,
  bulk_max_payload_size: 1_048_576
```

---

## Phoenix Integration

Add SCIM routes to your Phoenix application:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router

  pipeline :scim_api do
    plug :accepts, ["json", "scim+json"]
    plug ExScimPhoenix.Plug.ScimContentType
    plug ExScimPhoenix.Plug.ScimAuth
  end

  scope "/scim/v2" do
    pipe_through :scim_api
    use ExScimPhoenix.Router
  end
end
```

---

## Custom Adapters

### Storage Adapter

```elixir
defmodule MyApp.CustomStorage do
  @behaviour ExScim.Storage.Adapter

  def get_user(id), do: # your implementation
  def create_user(user_data), do: # your implementation
  # ... other callbacks
end
```

### Resource Mapper

```elixir
defmodule MyApp.UserMapper do
  @behaviour ExScim.Users.Mapper.Adapter

  def from_scim(scim_data) do
    %MyApp.User{
      username: scim_data["userName"],
      email: get_primary_email(scim_data["emails"])
    }
  end

  def to_scim(%MyApp.User{} = user, _opts) do
    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "id" => user.id,
      "userName" => user.username,
      "emails" => format_emails(user.email)
    }
  end
end
```

---

## Example Provider

The [`examples/provider`](./examples/provider) app shows a complete SCIM setup:

* Phoenix router with SCIM routes
* Domain ↔ SCIM mappers
* Ecto schema for `User`
* SQLite database
* Custom auth provider (demo)
* User and Group support

Run it locally:

```bash
cd examples/provider
mix deps.get
mix ecto.setup
mix phx.server
```

---

## Development

Each package can be tested independently:

```bash
cd ex_scim && mix test
cd ex_scim_ecto && mix test
cd ex_scim_phoenix && mix test
cd ex_scim_client && mix test
```

Provider example:

```bash
cd examples/provider
mix ecto.setup
mix phx.server
```

---

## SCIM 2.0 Support

**Features**

* User and Group resources ([RFC 7643 §4](https://www.rfc-editor.org/rfc/rfc7643#section-4))
* REST API ([RFC 7644](https://www.rfc-editor.org/rfc/rfc7644))
* JSON Patch ([RFC 6902](https://www.rfc-editor.org/rfc/rfc6902))
* SCIM filter expressions ([RFC 7644 §3.4.2.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2.2))
* Bulk operations ([RFC 7644 §3.7](https://www.rfc-editor.org/rfc/rfc7644#section-3.7))
* Discovery endpoints: ServiceProviderConfig, ResourceTypes, Schemas ([RFC 7644 §4](https://www.rfc-editor.org/rfc/rfc7644#section-4))
* RFC-compliant error responses ([RFC 7644 §3.12](https://www.rfc-editor.org/rfc/rfc7644#section-3.12))

**Endpoints**

* `GET /Users` – list with filtering, sorting, pagination ([RFC 7644 §3.4.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2))
* `POST /Users` – create ([RFC 7644 §3.3](https://www.rfc-editor.org/rfc/rfc7644#section-3.3))
* `GET /Users/{id}` – fetch by ID ([RFC 7644 §3.4.1](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.1))
* `PUT /Users/{id}` – replace ([RFC 7644 §3.5.1](https://www.rfc-editor.org/rfc/rfc7644#section-3.5.1))
* `PATCH /Users/{id}` – update ([RFC 7644 §3.5.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.5.2), [RFC 6902](https://www.rfc-editor.org/rfc/rfc6902))
* `DELETE /Users/{id}` – delete ([RFC 7644 §3.6](https://www.rfc-editor.org/rfc/rfc7644#section-3.6))
* Similar endpoints for Groups and Me ([RFC 7644 §3.11](https://www.rfc-editor.org/rfc/rfc7644#section-3.11))
* `POST /.search` – cross-resource search ([RFC 7644 §3.4.3](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.3))
* `POST /Bulk` – bulk operations ([RFC 7644 §3.7](https://www.rfc-editor.org/rfc/rfc7644#section-3.7))

---

## Design Choices

* **Modular**: use only the packages you need (core, ecto, phoenix)
* **Extensible**: adapters for storage, mapping, auth, validation
* **Separated concerns**: persistence, HTTP, business logic
* **RFC compliance**: responses and errors follow spec

---

See the [examples/provider](./examples/provider) app for a full reference implementation.
