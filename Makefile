ENV ?= dev
TF  := devops/scripts/tf.sh

.PHONY: help setup install dev test lint plan infra deploy deploy-backend deploy-web destroy mobile

help: ## Show commands
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[1m%-16s\033[0m %s\n", $$1, $$2}'

setup: ## First-time setup: name the project, connect AWS, optional first deploy
	./scripts/bootstrap.sh

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
	terraform fmt -check -recursive devops/terraform

plan: ## Preview infra changes: make plan ENV=dev
	$(TF) $(ENV) plan

infra: ## Apply infra: make infra ENV=dev
	$(TF) $(ENV) apply -auto-approve

deploy-backend: ## Build + roll out the Go binary
	devops/scripts/deploy-backend.sh $(ENV)

deploy-web: ## Build + publish the React app
	devops/scripts/deploy-web.sh $(ENV)

deploy: infra deploy-backend deploy-web ## Infra + backend + web for ENV
	@echo "API: $$($(TF) $(ENV) output -raw api_url)"
	@echo "Web: $$($(TF) $(ENV) output -raw web_url)"

destroy: ## Tear down an environment: make destroy ENV=dev
	$(TF) $(ENV) destroy

mobile: ## Start Expo pointed at your local backend
	cd mobile && EXPO_PUBLIC_API_URL=http://localhost:8080 npx expo start
