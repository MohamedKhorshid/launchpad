// Package notes is the example feature module. Copy its layout for new features:
//
//	notes.go    module wiring + HTTP handlers
//	service.go  business rules (no HTTP, no storage details)
//	store.go    Store interface + implementations
//	*_test.go   tests through the HTTP surface
//
// Delete this module once your first real module exists.
package notes

import (
	"errors"
	"net/http"

	"launchpad/backend/internal/platform/httpx"
)

type Module struct{ svc *Service }

func New(store Store) *Module { return &Module{svc: NewService(store)} }

func (m *Module) Name() string { return "notes" }

func (m *Module) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /v1/notes", m.list)
	mux.HandleFunc("POST /v1/notes", m.create)
	mux.HandleFunc("GET /v1/notes/{id}", m.get)
	mux.HandleFunc("DELETE /v1/notes/{id}", m.delete)
}

func (m *Module) list(w http.ResponseWriter, r *http.Request) {
	notes, err := m.svc.List(r.Context())
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "could not list notes")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"items": notes})
}

func (m *Module) create(w http.ResponseWriter, r *http.Request) {
	var in CreateInput
	if err := httpx.Decode(w, r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, err.Error())
		return
	}
	n, err := m.svc.Create(r.Context(), in)
	if errors.Is(err, ErrInvalid) {
		httpx.Error(w, http.StatusUnprocessableEntity, err.Error())
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "could not create note")
		return
	}
	httpx.JSON(w, http.StatusCreated, n)
}

func (m *Module) get(w http.ResponseWriter, r *http.Request) {
	n, err := m.svc.Get(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "note not found")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "could not get note")
		return
	}
	httpx.JSON(w, http.StatusOK, n)
}

func (m *Module) delete(w http.ResponseWriter, r *http.Request) {
	err := m.svc.Delete(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "note not found")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "could not delete note")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
