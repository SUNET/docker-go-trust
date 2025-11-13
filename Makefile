# Go-Trust Containerized Deployment Makefile

.PHONY: help build run stop logs clean test

# Default target
help: ## Show this help message
	@echo "Go-Trust  - Pure Binary with Controlled Dependencies"
	@echo "This builds the actual go-trust binary using dependency versions"
	@echo "controlled by  docker-go-trust (no cmd/ directory needed)."
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "Building docker-go-trust containerized image with custom LOTL..."
	docker build -f Dockerfile -t docker-go-trust:latest .



run: build ## Build and run docker-go-trust with docker-compose
	@echo "Starting containerized docker-go-trust with LOTL"
	docker-compose up -d


stop: ## Stop the running service
	@echo "Stopping containerized docker-go-trust"
	docker-compose down

logs: ## View service logs
	docker-compose logs -f docker-go-trust

restart: stop run ## Restart the service

status: ## Check service status
	@echo "Service Status:"
	docker-compose ps
	@echo ""
	@echo "Health Check:"
	@curl -s http://127.0.0.1:6001/healthz | jq . || echo "Service not responding"



# not the  best approach, need a separate container for this 
test: ## Run all tests (GitHub Actions workflow locally)
	@echo "Running go-trust tests with controlled dependencies..."
	@echo "This simulates the GitHub Actions workflow locally"
	@if [ ! -d "/tmp/go-trust-source" ]; then \
		echo "Cloning go-trust source"; \
		git clone https://github.com/SUNET/go-trust.git /tmp/go-trust-source; \
	fi
	@cd /tmp/go-trust-source && \
		echo "Setting up controlled dependencies..." && \
		echo 'module github.com/SUNET/go-trust' > go.mod.new && \
		echo '' >> go.mod.new && \
		echo 'go 1.25' >> go.mod.new && \
		echo '' >> go.mod.new && \
		if [ -f "$(PWD)/go.mod" ]; then \
			sed -n '/^require (/,/^)/{p}' "$(PWD)/go.mod" >> go.mod.new || true; \
			echo '' >> go.mod.new; \
			grep '^replace ' "$(PWD)/go.mod" >> go.mod.new || true; \
		fi && \
		mv go.mod.new go.mod && \
		if [ -f "$(PWD)/go.sum" ]; then \
			cp "$(PWD)/go.sum" ./; \
		fi && \
		echo "Installing dependencies..." && \
		go mod tidy && \
		go mod download && \
		go mod verify && \
		echo "Building..." && \
		go build -v ./... && \
		echo "Running tests..." && \
		go test -v -race -timeout 10m -coverprofile=coverage.txt -covermode=atomic ./... && \
		echo "All tests passed!"

