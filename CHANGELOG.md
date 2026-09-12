# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### All packages

#### Changed

- Dependency upgrades: `phoenix` (1.8.3 -> 1.8.13), `ecto`/`ecto_sql` (3.13 ->
3.14), `postgrex` (0.22.0 -> 0.22.4), `finch` (0.21.0 -> 0.23.0), `decimal` (2.3.0
-> 3.1.1)

### ex_scim_client

#### Changed

- `req` (0.5.17 -> 0.7.4), resolving [CVE-2026-49756](https://cna.erlef.org/cves/CVE-2026-49756.html)

## [0.2.1] - 2026-09-04

### ex_scim_ecto

#### Fixed

- `ex_scim` dependency widened from `~> 0.1.0` to `~> 0.2.0`

### ex_scim_phoenix

#### Fixed

- `ex_scim` dependency widened from `~> 0.1.0` to `~> 0.2.0`
- Bulk operation errors return underlying reason as `invalidSyntax` error

## [0.2.0] - 2026-04-04

### ex_scim

#### Breaking Changes

- Removed coarse `scim:write` scope; replaced with fine-grained `scim:create`,
`scim:update`, `scim:delete`

| New scope | Replaces | Covers |
|---|---|---|
| `scim:create` | `scim:write` | POST `/Users`, POST `/Groups`, POST operations in `/Bulk` |
| `scim:update` | `scim:write` | PUT/PATCH `/Users`, PUT/PATCH `/Groups`, PUT/PATCH operations in `/Bulk` |
| `scim:delete` | `scim:write` | DELETE `/Users`, DELETE `/Groups`, DELETE operations in `/Bulk` |

**Migration:** replace `"scim:write"` in every token or credential scope list in
your `AuthProvider.Adapter` implementation with the specific scopes that client
should have:

```elixir
# Before
scopes: ["scim:read", "scim:write"]

# After - full write access
scopes: ["scim:read", "scim:create", "scim:update", "scim:delete"]

# After - provisioning only (no delete)
scopes: ["scim:read", "scim:create", "scim:update"]
```

#### Added

- `scim:create`, `scim:update`, `scim:delete` scopes for fine-grained write authorization
- Per-operation scope enforcement in `ExScim.Operations.Bulk`
- `get_meta_version/1` deterministic ETag support via `:meta_version` field
- Scope reference table in `ExScim.Scope` module documentation
- Authorization Scopes section in the configuration guide

#### Fixed

- Preserve `meta_created` across PUT (replace) operations

### ex_scim_phoenix

#### Breaking Changes

- `/Bulk` scope enforcement now per-operation; failed operations return `403`
and count toward `failOnErrors`

#### Fixed

- `ETag` response header populated on POST/PUT/PATCH (was reading `meta.etag`
instead of `meta.version`, RFC 7643 3.1)
- `MeController` no longer raises when `meta.version` is absent

### examples/provider

#### Fixed

- `UserMapper`/`GroupMapper` no longer read server-assigned
`meta.created`/`meta.lastModified` from client payloads

## [0.1.2] - 2026-03-27

### ex_scim_ecto

#### Fixed

- Return HTTP 400 with SCIM validation errors instead of 500 when Ecto changeset
validation fails

### scim_tester

#### Added

- Schema-aware payload generation for create, update, patch, and bulk tests

### examples/provider

#### Fixed

- Relax User changeset to only require SCIM-mandatory fields (`userName`,
`externalId`, `active`), matching RFC 7643

## [0.1.1] - 2026-02-20

### ex_scim_ecto

#### Added

- `field_mapping` config option for domain-to-database value transformation
(e.g., `active: true/false` to `status: "active"/"inactive"`)
- Field mapping applied on reads, writes, and filter queries

### All packages

#### Added

- Hex package metadata (`description`, `package`, `source_url`) to all umbrella
apps
- `ex_doc` dependency for documentation generation
- Conditional `ex_scim` dependency resolution (umbrella vs Hex) in
`ex_scim_ecto` and `ex_scim_phoenix`

#### Improved

- Comprehensive `@moduledoc` and `@doc` annotations across all modules
- Expanded README for `ex_scim_ecto` and `ex_scim_phoenix`

## [0.1.0] - Initial Release

### ex_scim

#### Added

- Core SCIM v2.0 library implementation
- User and group resource management
- Bulk operations support
- Schema validation
- Query filter parsing and adapter pattern
- Filtering on complex SCIM attribute paths
- Filtering on associated tables in QueryFilter
- Storage adapter behaviour with ETS-based implementation
- Authentication provider adapter pattern
- Resource scope validation via `ExScim.Scope` struct with `tenant_id` and `metadata`
- Optional multi-tenancy support
- `ExScim.Tenant.Resolver` behaviour for resolving tenant context from requests
- Tenant-aware URL generation (`Config.resource_url/3`, `Config.collection_url/2`)
- Lifecycle hooks for SCIM operations (before/after create, update, delete)
- Configurable `resource_types` per provider
- Schema Builder DSL for declarative schema definitions
- Feature toggles on Router for enabling/disabling endpoints
- Caller parameter and result tuples in Mappers
- SCIM error response helpers
- Initial test suite

### ex_scim_client

#### Added

- HTTP client for consuming SCIM APIs
- User and Group resource operations
- Request builder with authentication

### ex_scim_ecto

#### Added

- Ecto-based storage adapter
- Query filter adapter for Ecto integration
- Configurable `lookup_key` option on storage adapter
- Configurable `tenant_key` option for discriminator-column multi-tenancy
- Automatic tenant scoping on all queries when `tenant_key` and
`scope.tenant_id` are set
- Tenant ID injection on resource creation

### ex_scim_phoenix

#### Added

- Phoenix integration for SCIM
- SCIM controllers and routing
- Authentication plugs and middleware (`ExScimPhoenix.Plugs.ScimTenant` for
tenant resolution)
- Scope assignment via `conn.assigns.scim_scope`
- Request logging
- Error handling

### examples/provider

#### Added

- LiveView-based provider example
- User and group management interface
- Database migrations and seeds
- Authentication integration

### scim_tester

#### Added

- Search composer with navbar, dedicated route, and result section
- Connect button to fetch server capabilities
- Re-run functionality for individual test cases
- Integration tests for filter operators
- Filter list built from schema
