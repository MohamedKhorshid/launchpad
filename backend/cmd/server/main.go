// Command server runs the backend as a single process (modular monolith).
// Every feature lives in internal/modules/<name> and is registered below.
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"launchpad/backend/internal/modules/health"
	"launchpad/backend/internal/modules/notes"
	"launchpad/backend/internal/platform/config"
	"launchpad/backend/internal/platform/module"
	"launchpad/backend/internal/platform/server"
)

// version is set at build time: -ldflags "-X main.version=<git sha>"
var version = "dev"

func main() {
	cfg := config.Load()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	slog.SetDefault(logger)

	// Register modules here. Order does not matter; each owns its own routes.
	modules := []module.Module{
		health.New(version),
		notes.New(notes.NewMemoryStore()),
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	srv := server.New(cfg, logger, modules)
	if err := srv.Run(ctx); err != nil {
		logger.Error("server stopped with error", "err", err)
		os.Exit(1)
	}
}
