package notes_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"launchpad/backend/internal/modules/notes"
)

func newServer() http.Handler {
	mux := http.NewServeMux()
	notes.New(notes.NewMemoryStore()).Register(mux)
	return mux
}

func do(t *testing.T, h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestNotesLifecycle(t *testing.T) {
	h := newServer()

	rec := do(t, h, "POST", "/v1/notes", `{"title":"hello","body":"world"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: got %d %s", rec.Code, rec.Body)
	}
	var n notes.Note
	if err := json.Unmarshal(rec.Body.Bytes(), &n); err != nil || n.ID == "" {
		t.Fatalf("create: bad response %s", rec.Body)
	}

	if rec := do(t, h, "GET", "/v1/notes/"+n.ID, ""); rec.Code != http.StatusOK {
		t.Fatalf("get: got %d", rec.Code)
	}
	if rec := do(t, h, "GET", "/v1/notes", ""); !strings.Contains(rec.Body.String(), n.ID) {
		t.Fatalf("list: missing note: %s", rec.Body)
	}
	if rec := do(t, h, "DELETE", "/v1/notes/"+n.ID, ""); rec.Code != http.StatusNoContent {
		t.Fatalf("delete: got %d", rec.Code)
	}
	if rec := do(t, h, "GET", "/v1/notes/"+n.ID, ""); rec.Code != http.StatusNotFound {
		t.Fatalf("get after delete: got %d", rec.Code)
	}
}

func TestCreateValidation(t *testing.T) {
	h := newServer()
	if rec := do(t, h, "POST", "/v1/notes", `{"title":"  "}`); rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("empty title: got %d", rec.Code)
	}
	if rec := do(t, h, "POST", "/v1/notes", `{"nope":1}`); rec.Code != http.StatusBadRequest {
		t.Fatalf("unknown field: got %d", rec.Code)
	}
}
