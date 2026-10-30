# Backend (Go modular monolith)

One binary, many modules. Stdlib only by default (`net/http` with Go 1.22+ route
patterns, `log/slog`). Add a dependency only when the stdlib is clearly worse.

## Structure

```
cmd/server/main.go           wiring: config, logger, module list, server
internal/platform/           feature-agnostic: config, server, httpx, module contract
internal/modules/<name>/     one folder per business capability
```

## Module rules

- A module implements `module.Module` (`Name()`, `Register(mux)`) and is added
  to the list in `cmd/server/main.go`.
- Layout per module: `<name>.go` (handlers), `service.go` (rules), `store.go`
  (Store interface + impls), `<name>_test.go` (tests via HTTP). Copy `notes`.
- **No cross-module imports of internals.** If module A needs B, B defines a
  small interface in `api.go`; `main.go` passes B's implementation into A.
- Routes are versioned: `/v1/<resource>`. `/health` stays unversioned.
- Errors: `httpx.Error(w, status, msg)` -> `{"error": "..."}`. Sentinel errors
  (`ErrNotFound`, `ErrInvalid`) map to 404/422 in handlers.
- Config comes from env vars via `internal/platform/config` (on EC2: `/etc/app/env`).

## Done means

`make lint && make test` pass, new endpoints have a test, and the web and
mobile `api.ts` clients expose the new endpoints.

## Storage

Default is `MemoryStore` (lost on restart). To add a real database, use the
`add-database` skill; it updates Terraform and adds a Store implementation.
