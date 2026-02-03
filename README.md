# ExScim

[![CI](https://github.com/ExScim/ex_scim_umbrella/actions/workflows/ci.yml/badge.svg)](https://github.com/ExScim/ex_scim_umbrella/actions/workflows/ci.yml)

SCIM 2.0 (RFC 7643/7644) implementation for Elixir.

## Packages

- **ex_scim** - Core library
- **ex_scim_client** - HTTP client
- **ex_scim_ecto** - Ecto storage adapter
- **ex_scim_phoenix** - Phoenix integration

## Quick Start

```bash
mix deps.get
mix test
```

## Examples

```bash
cd examples/provider && mix setup && mix phx.server  # http://localhost:4000
cd examples/client && mix setup && mix phx.server    # http://localhost:4001
```

## License

MIT
