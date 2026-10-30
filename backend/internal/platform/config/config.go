// Package config loads runtime settings from environment variables.
// On EC2 these come from /etc/launchpad/env, written by Terraform user data.
package config

import (
	"log/slog"
	"os"
	"strings"
	"time"
)

type Config struct {
	Env             string   // dev | prod | local
	Addr            string   // listen address, e.g. ":8080"
	AllowedOrigins  []string // CORS origins for the web app
	LogLevel        slog.Level
	ShutdownTimeout time.Duration
}

func Load() Config {
	return Config{
		Env:             get("APP_ENV", "local"),
		Addr:            get("APP_ADDR", ":8080"),
		AllowedOrigins:  split(get("APP_ALLOWED_ORIGINS", "*")),
		LogLevel:        level(get("APP_LOG_LEVEL", "info")),
		ShutdownTimeout: 15 * time.Second,
	}
}

func get(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

func split(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func level(s string) slog.Level {
	var l slog.Level
	if err := l.UnmarshalText([]byte(s)); err != nil {
		return slog.LevelInfo
	}
	return l
}
