# Gleamhub — BEAM / OTP patterns

You are working with concurrency on the Erlang target in Gleamhub.

## Where OTP is used

| Location | Pattern |
|----------|---------|
| `server/src/server.gleam` | `static_supervisor` (RestForOne): pog pool + pipeline events actor + Mist HTTP |
| `server/src/ci/events.gleam` | `gleam_otp` actor — SSE pub/sub for MR pipeline updates |
| `server/src/http/entry.gleam` | Mist adapter (not OTP, but BEAM process lifecycle) |
| `ci-worker/src/ci_worker.gleam` | `static_supervisor` (OneForOne) + coordinator actor |
| `ci-worker/src/ci_worker/coordinator.gleam` | Long-poll loop, spawn jobs via Erlang FFI |

The **UI** (`ui/`) is JavaScript target — no OTP there.

## Server supervisor tree

```
static_supervisor (RestForOne)
├── pog supervised pool
├── ci/events actor (pipeline_events_name)
└── mist supervised web listener
```

RestForOne: if web crashes, events actor and DB pool restart with it. Do not add unsupervised long-running processes.

## Pipeline events actor (`ci/events.gleam`)

Purpose: fan-out pipeline JSON to SSE subscribers per merge request.

Messages:
- `Subscribe(merge_request_id, subscriber)`
- `Unsubscribe(merge_request_id, subscriber)`
- `Publish(merge_request_id, payload)`

API:
- `publish_run(name, run)` — encode via `json/api` and publish
- Used by CI internal routes when job state changes
- SSE route in `ci/stream_routes.gleam` subscribes Mist connection

**When adding real-time server push:** extend this actor pattern, do not invent ad-hoc global mutable state.

## CI worker actor (`ci-worker/`)

Coordinator actor loop:
1. `Poll` → `GET /internal/ci/jobs/next` (long-poll)
2. On job → spawn linked Erlang process via FFI (`spawn_job`) to run Dagger
3. `JobFinished` → poll again
4. Backoff on HTTP errors

Worker is **stateless** regarding job queue — server owns queue in Postgres.

Do not add Gleam-side job queue state; use internal API + DB.

## Process naming

```gleam
let pool_name = process.new_name("server")
let pipeline_events_name = process.new_name("gleamhub.pipeline_events")
```

Pass names through `Context` for publish/subscribe.

## Mist + Wisp

HTTP is served by Mist, not a raw OTP gen_server. The supervised child is Mist's listener.

SSE uses `mist.server_sent_events` — blocking connection handled by Mist, not a custom gen_server.

## Error handling / failure modes

- Supervised children restart on crash (`wisp.rescue_crashes` catches handler panics per-request)
- Actors should `actor.continue(state)` — avoid unhandled message crashes
- ci-worker: log and backoff on transient API failures

## When to use an actor vs pure functions

| Use actor | Use pure fn |
|-----------|-------------|
| Pub/sub, subscription registry | Request/response handlers |
| Long-poll worker loop | Database queries |
| Process mailbox coordination | Git subprocess calls |

Default to pure functions. Add actors only for ongoing process state (subscribers, poll loops).

## FFI note

ci-worker uses `@external(erlang, ...)` for spawning — follow existing `ci_worker_spawn_ffi` pattern; do not add Rust/NIFs.

## Checklist for new background work

Prefer server-driven queue (Postgres + internal API) over in-memory queues.

1. [ ] Can this be a request handler + DB row? → do that first
2. [ ] Needs long-running poll/worker? → separate crate or supervised actor like ci-worker
3. [ ] Needs live UI updates? → publish through `ci/events` or extend it
4. [ ] Document env vars and internal API routes

## Anti-patterns

- GenServer-style hidden mutable state in route handlers
- Unsupervised `process.spawn` for critical work
- Shared ETS without an owning actor
- Oban/Phoenix.Process analogies — use gleam_otp actors + supervisors
