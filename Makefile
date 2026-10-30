ENV       ?= dev
COMPONENT ?= all
RUN       := scripts/run-workflow.sh

.PHONY: help setup install dev test lint mobile deploy plan status mobile-build logs

help: ## Show commands
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[1m%-14s\033[0m %s\n", $$1, $$2}'

# ---------- local development (no AWS) ----------

setup: ## One-time: connect this repo to an AWS account (runs on GitHub Actions)
	./scripts/setup.sh

install: ## Install all dependencies
	cd backend && go mod download
	cd web && npm ci
	cd mobile && npm ci

dev: ## Run backend (:8080) and web (:5173) together
	@trap 'kill 0' INT TERM; \
	(cd backend && go run ./cmd/server) & \
	(cd web && npm run dev) & \
	wait

test: ## Run every test suite
	cd backend && go test ./...
	cd web && npm test
	cd mobile && npm run typecheck

lint: ## Lint and format checks
	$(MAKE) -C backend lint
	cd web && npm run typecheck

mobile: ## Start Expo pointed at your local backend
	cd mobile && EXPO_PUBLIC_API_URL=http://localhost:8080 npx expo start

# ---------- AWS: everything runs in GitHub Actions ----------
# Push your commits first; workflows build what is on GitHub.

deploy: ## Deploy via Actions: make deploy ENV=dev COMPONENT=all|infra|backend|web
	$(RUN) deploy.yml -f env=$(ENV) -f component=$(COMPONENT)

plan: ## Terraform plan via Actions (no changes applied): make plan ENV=dev
	$(RUN) plan.yml -f env=$(ENV)

status: ## Recent workflow runs
	gh run list --limit 10

logs: ## Logs of the latest run of a workflow: make logs WF=deploy.yml
	gh run view $$(gh run list --workflow $(or $(WF),deploy.yml) --limit 1 --json databaseId -q '.[0].databaseId') --log

mobile-build: ## EAS build via Actions: make mobile-build PROFILE=preview ENV=dev
	$(RUN) mobile-release.yml -f profile=$(or $(PROFILE),preview) -f env=$(ENV) -f platform=all
