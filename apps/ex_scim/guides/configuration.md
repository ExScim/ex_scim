# Configuration & Guides

## Configuration Reference

All options are set under `config :ex_scim`.

### Core

| Key | Default | Description |
|-----|---------|-------------|
| `:base_url` | `"http://localhost:4000"` | Base URL for SCIM endpoints. Falls back to `SCIM_BASE_URL` env var. |
| `:storage_strategy` | `ExScim.Storage.EtsStorage` | Module implementing `ExScim.Storage.Adapter` |
| `:auth_provider_adapter` | *required* | Module implementing `ExScim.Auth.AuthProvider.Adapter` |

### Resource Mapping

| Key | Default | Description |
|-----|---------|-------------|
| `:user_resource_mapper` | `ExScim.Users.Mapper.DefaultMapper` | Module implementing `ExScim.Users.Mapper.Adapter` |
| `:group_resource_mapper` | `ExScim.Groups.Mapper.DefaultMapper` | Module implementing `ExScim.Groups.Mapper.Adapter` |

### Ecto Storage (`ex_scim_ecto`)

| Key | Default | Description |
|-----|---------|-------------|
| `:storage_repo` | *required* | Your Ecto `Repo` module |
| `:user_model` | *required* | Ecto schema module or `{Schema, opts}` tuple |
| `:group_model` | *required* | Same format as `:user_model` |

When using the `{Schema, opts}` tuple form, available sub-options are:

- `:preload` - list of associations to preload (default `[]`)
- `:lookup_key` - primary key field (default `:id`)
- `:filter_mapping` - map of SCIM attribute paths to DB columns (default `%{}`)
- `:tenant_key` - column used for multi-tenant scoping (default `nil`)
- `:field_mapping` - map of domain fields to `{db_field, to_storage_fn, from_storage_fn}` tuples for value transformation (default `%{}`)

```elixir
config :ex_scim,
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: MyApp.Repo,
  user_model:
    {MyApp.Accounts.User,
     preload: [:roles],
     lookup_key: :uuid,
     filter_mapping: %{"emails.value" => :email},
     tenant_key: :organization_id,
     field_mapping: %{
       active: {:status,
         fn true -> "active"; false -> "inactive" end,
         fn "active" -> true; _ -> false end}
     }},
  group_model:
    {MyApp.Groups.Group,
     preload: [:members],
     tenant_key: :organization_id}
```

### Capabilities

Reported in the ServiceProviderConfig discovery endpoint.

| Key | Default |
|-----|---------|
| `:patch_supported` | `false` |
| `:bulk_supported` | `true` |
| `:bulk_max_operations` | `1000` |
| `:bulk_max_payload_size` | `1_048_576` |
| `:filter_supported` | `false` |
| `:filter_max_results` | `200` |
| `:sort_supported` | `false` |
| `:change_password_supported` | `false` |
| `:etag_supported` | `false` |

### Discovery

| Key | Default | Description |
|-----|---------|-------------|
| `:documentation_uri` | `nil` | URI included in ServiceProviderConfig |
| `:authentication_schemes` | `[]` | List of scheme maps per RFC 7643 |
| `:resource_types` | User + Group | List of resource type maps |
| `:schema_modules` | Built-in User, EnterpriseUser, Group | Schema definition modules |

### Lifecycle & Tenancy

| Key | Default | Description |
|-----|---------|-------------|
| `:lifecycle_adapter` | `nil` | Module implementing `ExScim.Lifecycle.Adapter` |
| `:tenant_resolver` | `nil` | Module implementing `ExScim.Tenant.Resolver` |

## Multi-Tenancy

Multi-tenancy is opt-in. When no `tenant_resolver` is configured (or `scope.tenant_id` is `nil`), the system operates in single-tenant mode with no isolation applied.

To enable it, wire up three pieces:

1. **Tenant resolver** - implement `ExScim.Tenant.Resolver` to extract a tenant identifier from the request (header, subdomain, path, etc.).
2. **Phoenix plug** - add `ExScimPhoenix.Plugs.ScimTenant` to your SCIM pipeline after `ScimAuth`.
3. **Ecto tenant key** - set `:tenant_key` on your model tuples so queries are scoped and creates inject the tenant ID.

```elixir
# 1. Resolver
defmodule MyApp.TenantResolver do
  @behaviour ExScim.Tenant.Resolver

  @impl true
  def resolve_tenant(conn, _scope) do
    case Plug.Conn.get_req_header(conn, "x-tenant-id") do
      [tenant_id] -> {:ok, tenant_id}
      _ -> {:error, :missing_tenant}
    end
  end
end

# 2. Config
config :ex_scim,
  tenant_resolver: MyApp.TenantResolver,
  user_model: {MyApp.Accounts.User, tenant_key: :organization_id},
  group_model: {MyApp.Groups.Group, tenant_key: :organization_id}

# 3. Pipeline
#    Add: plug ExScimPhoenix.Plugs.ScimTenant
```

The resolver can optionally implement `tenant_scim_base_url/1` to generate tenant-specific resource location URLs (e.g., `https://acme.example.com/scim/v2`).

## Custom Adapters

### Storage Adapter

Implement the `ExScim.Storage.Adapter` behaviour to use a custom data store:

```elixir
defmodule MyApp.CustomStorage do
  @behaviour ExScim.Storage.Adapter

  def get_user(id), do: # your implementation
  def create_user(user_data), do: # your implementation
  # ... other callbacks
end
```

### Resource Mapper

Implement `ExScim.Users.Mapper.Adapter` or `ExScim.Groups.Mapper.Adapter` to control how domain structs map to SCIM JSON:

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

## Endpoints

All endpoints are served under the scope you configure (typically `/scim/v2`).

### Users

| Method | Path | Description | RFC |
|--------|------|-------------|-----|
| `GET` | `/Users` | List with filtering, sorting, pagination | [§3.4.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.2) |
| `POST` | `/Users` | Create | [§3.3](https://www.rfc-editor.org/rfc/rfc7644#section-3.3) |
| `GET` | `/Users/{id}` | Fetch by ID | [§3.4.1](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.1) |
| `PUT` | `/Users/{id}` | Replace | [§3.5.1](https://www.rfc-editor.org/rfc/rfc7644#section-3.5.1) |
| `PATCH` | `/Users/{id}` | Partial update (JSON Patch) | [§3.5.2](https://www.rfc-editor.org/rfc/rfc7644#section-3.5.2) |
| `DELETE` | `/Users/{id}` | Delete | [§3.6](https://www.rfc-editor.org/rfc/rfc7644#section-3.6) |

Groups and Me follow the same pattern. See [RFC 7644 §3.11](https://www.rfc-editor.org/rfc/rfc7644#section-3.11) for Me endpoint details.

### Other

| Method | Path | Description | RFC |
|--------|------|-------------|-----|
| `POST` | `/.search` | Cross-resource search | [§3.4.3](https://www.rfc-editor.org/rfc/rfc7644#section-3.4.3) |
| `POST` | `/Bulk` | Bulk operations | [§3.7](https://www.rfc-editor.org/rfc/rfc7644#section-3.7) |
| `GET` | `/ServiceProviderConfig` | Server capabilities | [§4](https://www.rfc-editor.org/rfc/rfc7644#section-4) |
| `GET` | `/ResourceTypes` | Supported resource types | [§4](https://www.rfc-editor.org/rfc/rfc7644#section-4) |
| `GET` | `/Schemas` | Schema definitions | [§4](https://www.rfc-editor.org/rfc/rfc7644#section-4) |
