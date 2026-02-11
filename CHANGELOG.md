# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ex_scim
#### Added
- Lifecycle hooks for SCIM operations (before/after create, update, delete)
- Configurable `resource_types` per provider
- Schema Builder DSL for declarative schema definitions
- Feature toggles on Router for enabling/disabling endpoints
- Caller parameter and result tuples in Mappers
- Filtering on complex SCIM attribute paths
- Filtering on associated tables in QueryFilter

#### Changed
- Full namespace for resource protocol implementations
- `Principal` helper no longer raises on construction

#### Fixed
- SCIM filter pipeline
- MeController plug uses `:show` instead of `:read`

### ex_scim_ecto
#### Added
- Configurable `lookup_key` option on storage adapter

#### Changed
- Removed unused lookup functions from storage adapter

#### Fixed
- Ecto query generation for filters

### ex_scim_phoenix
#### Fixed
- Colocated hooks location

### scim_tester (formerly examples/client)
#### Added
- Search composer with navbar, dedicated route, and result section
- Connect button to fetch server capabilities
- Re-run functionality for individual test cases
- Integration tests for filter operators
- Filter list built from schema

#### Changed
- Moved from `examples/client` to top-level `scim_tester/`
- Replaced font icons with SVGs in log messages
- Removed page size elements from filter card
- No longer shows initial empty search filter row

## [0.1.0] - Initial Release

### ex_scim
#### Added
- Core SCIM v2.0 library implementation
- User and group resource management
- Bulk operations support
- Schema validation
- Query filter parsing and adapter pattern
- Storage adapter behaviour with ETS-based implementation
- Authentication provider adapter pattern
- Resource scope validation
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

### ex_scim_phoenix
#### Added
- Phoenix integration for SCIM
- SCIM controllers and routing
- Authentication plugs and middleware
- Request logging
- Error handling improvements

### examples/provider
#### Added
- LiveView-based provider example
- User and group management interface
- Database migrations and seeds
- Authentication integration
