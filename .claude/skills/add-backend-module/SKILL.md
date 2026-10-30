---
name: add-backend-module
description: Add a new business module (feature) to the Go modular monolith, including tests and typed clients for web and mobile. Use when the user asks for a new backend feature, resource, endpoint group, or module.
---

# Add a backend module

Reference implementation: `backend/internal/modules/notes/`.

## Steps

1. **Name it** after a business capability, singular package, plural routes:
   package `listing`, routes `/v1/listings`. Check `docs/product/spec.md` for the API.
2. **Create `backend/internal/modules/<name>/`**:
   - `<name>.go` - `Module` struct, `New(...)`, `Name()`, `Register(mux)`, handlers.
     Routes use Go 1.22 patterns: `mux.HandleFunc("GET /v1/listings/{id}", m.get)`.
   - `service.go` - domain types, validation, business rules, sentinel errors.
   - `store.go` - `Store` interface + implementation (memory, or the DB from `add-database`).
   - `<name>_test.go` - table-driven tests through `httptest`, covering happy
     path, validation (422), not found (404).
   - `api.go` (only if other modules need it) - small exported interface.
3. **Register** it in `backend/cmd/server/main.go`. If it depends on another
   module, inject that module's interface here; never import internals.
4. **Clients**: add typed functions and types to `web/src/api.ts` and
   `mobile/src/api.ts`. Field names match the Go JSON tags (camelCase).
5. **Verify**: `cd backend && make lint && make test`, then `cd web && npm test`.
6. If the module replaces the `notes` example, delete `notes` and its client
   functions and screens.

## Conventions

- JSON in/out via `httpx.Decode` / `httpx.JSON` / `httpx.Error`.
- IDs are strings. Timestamps are UTC, RFC3339 (`time.Time` marshals this way).
- Pagination when lists can grow: `?limit=&cursor=` returning `{items, nextCursor}`.
- Auth: if sign-in exists, read the user from request context set by middleware
  in `internal/platform`; don't parse tokens inside modules.
