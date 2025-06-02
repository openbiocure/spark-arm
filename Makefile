# Variables
PYTHON := python3
DOCKER_BUILDER := $(PYTHON) -m scripts.docker-builder
COMPONENT ?= spark
DOCKER_TAG ?= latest
DOCKER_REGISTRY ?= localhost:5000

# Default target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make dockerfile COMPONENT=<name>  - Render Dockerfile for component"
	@echo "  make build COMPONENT=<name>       - Build Docker image for component"
	@echo "  make push COMPONENT=<name>        - Push Docker image to registry"
	@echo "  make list                         - List available components"
	@echo ""
	@echo "Variables:"
	@echo "  COMPONENT     - Component name (default: spark)"
	@echo "  DOCKER_TAG    - Docker image tag (default: latest)"
	@echo "  DOCKER_REGISTRY - Docker registry (default: localhost:5000)"

# List available components
.PHONY: list
list:
	$(DOCKER_BUILDER) list-components

# Render Dockerfile
.PHONY: dockerfile
dockerfile:
	$(DOCKER_BUILDER) render $(COMPONENT)

# Build Docker image
.PHONY: build
build: dockerfile
	docker build -t $(DOCKER_REGISTRY)/$(COMPONENT):$(DOCKER_TAG) docker/output/$(COMPONENT)

# Push Docker image
.PHONY: push
push: build
	docker push $(DOCKER_REGISTRY)/$(COMPONENT):$(DOCKER_TAG)

# Clean generated files
.PHONY: clean
clean:
	rm -rf docker/output/*

# Install Python dependencies
.PHONY: install
install:
	pip install -r requirements.txt

# Development setup
.PHONY: dev
dev: install
	pip install -e .

# Test rendering
.PHONY: test
test: install
	$(DOCKER_BUILDER) render spark --output-dir docker/output/test
	$(DOCKER_BUILDER) render hive --output-dir docker/output/test 