// Package module defines the contract every feature module implements.
//
// Rules of the modular monolith:
//   - A module lives in internal/modules/<name> and owns its routes, logic and storage.
//   - Modules never import another module's internals. If module A needs B,
//     B exposes a small interface in its api.go and main.go wires it into A.
//   - Shared, feature-agnostic code goes in internal/platform.
package module

import "net/http"

type Module interface {
	// Name is a short identifier used in logs, e.g. "notes".
	Name() string
	// Register adds the module's routes, using Go 1.22+ patterns
	// such as "GET /v1/notes/{id}".
	Register(mux *http.ServeMux)
}
