VERSION ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
LDFLAGS := -s -w -X main.version=$(VERSION)

.PHONY: run test lint build build-linux

run: ## Run locally on :8080
	go run ./cmd/server

test:
	go test -race ./...

lint:
	go vet ./...
	@test -z "$$(gofmt -l .)" || (echo "gofmt needed:"; gofmt -l .; exit 1)

build:
	go build -ldflags "$(LDFLAGS)" -o bin/server ./cmd/server

# Binary for the EC2 instance (Graviton / arm64, Amazon Linux 2023)
build-linux:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o bin/server-linux-arm64 ./cmd/server
