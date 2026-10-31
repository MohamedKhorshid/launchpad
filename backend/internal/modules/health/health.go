// Package health exposes liveness for gateway checks and deploy verification.
package health

import (
	"net/http"
	"time"

	"launchpad/backend/internal/platform/httpx"
)

type Module struct {
	version string
	started time.Time
}

func New(version string) *Module { return &Module{version: version, started: time.Now()} }

func (m *Module) Name() string { return "health" }

func (m *Module) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		httpx.JSON(w, http.StatusOK, map[string]any{
			"status":  "ok",
			"version": m.version,
			"uptime":  time.Since(m.started).Round(time.Second).String(),
		})
	})
}
