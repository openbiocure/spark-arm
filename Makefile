# Variables
PYTHON := python3
VENV_DIR := .venv
VENV_BIN := $(VENV_DIR)/bin
VENV_PYTHON := $(VENV_DIR)/bin/python
VENV_PIP := $(VENV_DIR)/bin/pip
DOCKER_BUILDER := $(VENV_DIR)/bin/docker-builder
COMPONENT ?= spark
DOCKER_TAG ?= v0.6.2
DOCKER_REGISTRY ?= ghcr.io/openbiocure/spark-arm
CONFIG_PATH ?= docker/configs/versions.yaml

# Docker builder sync configuration
REMOTE_USER ?= pi
REMOTE_HOST ?= 172.16.11.90
REMOTE_DIR ?= /home/pi/spark-py
LOCAL_DIR ?= $(shell pwd)
EXCLUDE_PATTERNS ?= .git .venv __pycache__ *.pyc .DS_Store

# Convert exclude patterns to rsync exclude options
RSYNC_EXCLUDES := $(patsubst %,--exclude=%,$(EXCLUDE_PATTERNS))

# Virtual environment targets
.PHONY: venv venv-clean venv-update setup

venv: $(VENV_DIR)/bin/activate ## Create virtual environment if it doesn't exist
	@echo "Virtual environment is ready at $(VENV_DIR)"

$(VENV_DIR)/bin/activate: requirements.txt
	@echo "Creating virtual environment..."
	@$(PYTHON) -m venv $(VENV_DIR)
	@echo "Upgrading pip..."
	@$(VENV_PIP) install --upgrade pip
	@echo "Installing dependencies..."
	@$(VENV_PIP) install -r requirements.txt
	@$(VENV_PIP) install -e .
	@touch $(VENV_DIR)/bin/activate

venv-clean: ## Remove virtual environment
	@echo "Removing virtual environment..."
	@rm -rf $(VENV_DIR)

venv-update: venv-clean venv ## Recreate virtual environment from scratch
	@echo "Virtual environment has been updated"

setup: venv ## Set up development environment
	@echo "Development environment is ready"
	@echo "To activate the virtual environment, run:"
	@echo "  source $(VENV_DIR)/bin/activate"

# Docker Compose targets
.PHONY: compose-up compose-down compose-logs compose-ps compose-restart

compose-up: ## Start the Spark stack
	@echo "Starting Spark stack..."
	@docker-compose up -d

compose-down: ## Stop and remove the Spark stack
	@echo "Stopping Spark stack..."
	@docker-compose down

compose-logs: ## Show logs from all services
	@docker-compose logs -f

compose-ps: ## List running services
	@docker-compose ps

compose-restart: compose-down compose-up ## Restart the Spark stack

# Default target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make setup          - Set up development environment"
	@echo "  make venv           - Create virtual environment"
	@echo "  make venv-clean     - Remove virtual environment"
	@echo "  make venv-update    - Recreate virtual environment"
	@echo ""
	@echo "  make dockerfile COMPONENT=<name>  - Render Dockerfile for component"
	@echo "  make build COMPONENT=<name>       - Build Docker image for component"
	@echo "  make push COMPONENT=<name>        - Push Docker image to registry"
	@echo "  make list                         - List available components"
	@echo ""
	@echo "  make compose-up     - Start the Spark stack"
	@echo "  make compose-down   - Stop and remove the Spark stack"
	@echo "  make compose-logs   - Show logs from all services"
	@echo "  make compose-ps     - List running services"
	@echo "  make compose-restart - Restart the Spark stack"
	@echo ""
	@echo "Variables:"
	@echo "  VENV_DIR        - Virtual environment directory (default: .venv)"
	@echo "  COMPONENT       - Component name (default: spark)"
	@echo "  DOCKER_TAG      - Docker image tag (default: v0.6.2)"
	@echo "  DOCKER_REGISTRY - Docker registry (default: ghcr.io/openbiocure/spark-arm)"
	@echo ""
	@echo "Available sync targets:"
	@echo "  sync        - Sync local changes to remote worker node"
	@echo "  sync-dry    - Show what would be synced without making changes"
	@echo "  sync-clean  - Clean remote directory before syncing"
	@echo ""
	@echo "Configuration (can be overridden):"
	@echo "  REMOTE_USER=$(REMOTE_USER)"
	@echo "  REMOTE_HOST=$(REMOTE_HOST)"
	@echo "  REMOTE_DIR=$(REMOTE_DIR)"
	@echo "  LOCAL_DIR=$(LOCAL_DIR)"
	@echo "  EXCLUDE_PATTERNS=$(EXCLUDE_PATTERNS)"
	@echo ""
	@echo "Environment Variables (required for compose):"
	@echo "  AWS_ENDPOINT_URL      - MinIO/S3 endpoint URL"
	@echo "  AWS_ACCESS_KEY_ID     - MinIO/S3 access key"
	@echo "  AWS_SECRET_ACCESS_KEY - MinIO/S3 secret key"
	@echo "  SPARK_SQL_WAREHOUSE_DIR - Spark SQL warehouse directory"
	@echo "  POSTGRES_HOST         - External PostgreSQL host"
	@echo "  POSTGRES_USER         - PostgreSQL user"
	@echo "  POSTGRES_PASSWORD     - PostgreSQL password"
	@echo "  POSTGRES_DB           - PostgreSQL database (default: hive)"
	@echo "  POSTGRES_PORT         - PostgreSQL port (default: 5432)"

# List available components
.PHONY: list
list: venv
	$(DOCKER_BUILDER) list_components

# Render Dockerfile
.PHONY: dockerfile
dockerfile: venv
	$(DOCKER_BUILDER) render $(COMPONENT) --config $(CONFIG_PATH) --output docker/output

# Build Docker image
.PHONY: build
build: dockerfile
	docker build -t $(DOCKER_REGISTRY)/$(COMPONENT):$(DOCKER_TAG) -f docker/output/Dockerfile.$(COMPONENT) docker/output

# Push Docker image
.PHONY: push
push: build
	docker push $(DOCKER_REGISTRY)/$(COMPONENT):$(DOCKER_TAG)

# Clean generated files
.PHONY: clean
clean:
	rm -rf docker/output/*

# Test rendering
.PHONY: test
test: venv
	$(DOCKER_BUILDER) render spark --output docker/output/test
	$(DOCKER_BUILDER) render hive --output docker/output/test

.PHONY: sync sync-dry sync-clean

sync: ## Sync local changes to remote worker node
	@echo "Syncing project files to $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_DIR)..."
	@rsync -avz --delete --exclude-from=rsync-ignore.txt \
		. \
		$(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_DIR)/

sync-dry: ## Show what would be synced without making changes
	@echo "Dry run sync from $(LOCAL_DIR) to $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_DIR)..."
	@rsync -avzn --delete --exclude-from=rsync-ignore.txt \
		. \
		$(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_DIR)/

sync-clean: ## Clean remote directory before syncing
	@echo "Cleaning remote directory before sync..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "rm -rf $(REMOTE_DIR)/*"
	@$(MAKE) sync