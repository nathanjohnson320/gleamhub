# server

[![Package Version](https://img.shields.io/hexpm/v/server)](https://hex.pm/packages/server)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/server/)

A Gleam project

## Quick start

```sh
gleam run   # Run the project
gleam test  # All tests — starts temporary Postgres via Docker on port 5433
gleam shell # Run an Erlang shell
```

### Database integration tests

`gleam test` always starts a temporary Postgres container on port **5433** (`docker-compose.test.yml`), runs migrations, runs all tests, then tears it down. Requires Docker and Node (for `dbmate`).

If Docker is not running or setup fails, **`gleam test` exits immediately** with the error.

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add server
```

and its documentation can be found at <https://hexdocs.pm/server>.
