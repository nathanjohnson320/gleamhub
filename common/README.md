# common

Shared Gleam library for the Gleamhub monorepo. The server depends on it via a path dependency in `gleam.toml`.

This package is intentionally small - add cross-cutting types and helpers here when both server and other crates need them.

## Development

```bash
cd common
gleam test
```

There is no standalone application in this crate.
