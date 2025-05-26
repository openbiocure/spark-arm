.PHONY: shell run attach-shell kill-shell clean test stop-test build push inspect

# Variables
HIVE_IMAGE_NAME ?= ghcr.io/openbiocure/hive-arm
HIVE_CONTAINER_NAME ?= hive-test
HIVE_VERSION ?= $(shell cat ../tag)
VERSIONS_SCRIPT ?= ../versions.sh

# Load environment variables
include ../debug.env
export

# Build the Hive Docker image
build:
	@echo "Building Hive Docker image..."
	@TAG=$$(cat ../tag); \
	BUILD_ARGS=$$(bash $(VERSIONS_SCRIPT) | grep -v '^#' | grep -v '^$$' | tr '\n' ' ' | sed 's/^ *//;s/ *$$//' | awk '{for(i=1;i<=NF;i++) printf "--build-arg %s ", $$i}'); \
	BUILD_CMD="docker build --platform linux/arm64 -t hive-arm:$$TAG $$BUILD_ARGS --build-arg IMAGE_VERSION=$$TAG -f Dockerfile ."; \
	echo "Debug: Build command: $$BUILD_CMD"; \
	eval "$$BUILD_CMD"; \
	docker tag hive-arm:$$TAG $(HIVE_IMAGE_NAME):$(HIVE_VERSION); \
	docker tag hive-arm:$$TAG $(HIVE_IMAGE_NAME):latest

# Push the Hive Docker image to registry
push:
	@echo "Pushing Hive Docker image..."
	@TAG=$$(cat ../tag); \
	docker tag $(HIVE_IMAGE_NAME):$(HIVE_VERSION) $(HIVE_IMAGE_NAME):stable; \
	docker push $(HIVE_IMAGE_NAME):$(HIVE_VERSION); \
	docker push $(HIVE_IMAGE_NAME):latest; \
	docker push $(HIVE_IMAGE_NAME):stable

# Test Hive container locally
test:
	@echo "Testing Hive container locally..."
	@echo "Loading environment variables from debug.env..."
	@echo "Creating required directories..."
	@rm -rf $(PWD)/logs
	@-mkdir -p $(PWD)/warehouse $(PWD)/logs 2>/dev/null || true
	@echo "Stopping and removing existing container if any..."
	@docker stop $(HIVE_CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(HIVE_CONTAINER_NAME) 2>/dev/null || true
	@echo "Starting Hive container..."
	@docker run -d \
		--name $(HIVE_CONTAINER_NAME) \
		--platform linux/arm64 \
		-p 9083:9083 \
		-e HIVE_METASTORE_DB_HOST=$${POSTGRES_HOST:-postgresql} \
		-e HIVE_METASTORE_DB_PORT=$${POSTGRES_PORT:-5432} \
		-e HIVE_METASTORE_DB_NAME=$${POSTGRES_DB:-hive} \
		-e HIVE_METASTORE_DB_USER=$${POSTGRES_USER:-hive} \
		-e HIVE_METASTORE_DB_PASSWORD=$${POSTGRES_PASSWORD:-hive} \
		-e HIVE_WAREHOUSE_DIR=/opt/hive/warehouse \
		-e HIVE_SCRATCH_DIR=/opt/hive/scratch \
		-e HIVE_LOG_LEVEL=DEBUG \
		-e HIVE_METASTORE_URI=thrift://localhost:9083 \
		-v $(PWD)/warehouse:/opt/hive/warehouse \
		-v $(PWD)/logs:/opt/hive/logs \
		$(HIVE_IMAGE_NAME):$(HIVE_VERSION)
	@echo "Container started. Checking logs..."
	@sleep 5
	@docker logs $(HIVE_CONTAINER_NAME)
	@echo "To follow logs: docker logs -f $(HIVE_CONTAINER_NAME)"
	@echo "To stop container: make stop-test"
	@echo "To inspect container: make shell"

# Stop and remove test container
stop-test:
	@echo "Stopping and removing test container..."
	@docker stop $(HIVE_CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(HIVE_CONTAINER_NAME) 2>/dev/null || true

# Get a shell in the container
shell:
	@if docker ps -q -f name=$(HIVE_CONTAINER_NAME) | grep -q .; then \
		echo "Container is running, connecting to it..."; \
		docker exec -it $(HIVE_CONTAINER_NAME) /bin/bash; \
	else \
		echo "Container is not running, starting a new one..."; \
		docker stop $(HIVE_CONTAINER_NAME) 2>/dev/null || true; \
		docker rm $(HIVE_CONTAINER_NAME) 2>/dev/null || true; \
		docker run -it \
			--name $(HIVE_CONTAINER_NAME) \
			--platform linux/arm64 \
			--entrypoint /bin/bash \
			-e HIVE_METASTORE_DB_HOST=$${POSTGRES_HOST:-postgresql} \
			-e HIVE_METASTORE_DB_PORT=$${POSTGRES_PORT:-5432} \
			-e HIVE_METASTORE_DB_NAME=$${POSTGRES_DB:-hive} \
			-e HIVE_METASTORE_DB_USER=$${POSTGRES_USER:-hive} \
			-e HIVE_METASTORE_DB_PASSWORD=$${POSTGRES_PASSWORD:-hive} \
			-e HIVE_WAREHOUSE_DIR=/opt/hive/warehouse \
			-e HIVE_SCRATCH_DIR=/opt/hive/scratch \
			-e HIVE_LOG_LEVEL=DEBUG \
			-e HIVE_METASTORE_URI=thrift://localhost:9083 \
			-v $(PWD)/warehouse:/opt/hive/warehouse \
			-v $(PWD)/logs:/opt/hive/logs \
			$(HIVE_IMAGE_NAME):$(HIVE_VERSION); \
	fi

# Get a debug shell in a clean container (without metastore service)
debug-shell:
	@echo "Starting a clean container with just a shell..."
	@docker stop $(HIVE_CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(HIVE_CONTAINER_NAME) 2>/dev/null || true
	@docker run -it \
		--name $(HIVE_CONTAINER_NAME) \
		--platform linux/arm64 \
		--entrypoint /bin/bash \
		-e HIVE_METASTORE_DB_HOST=$${POSTGRES_HOST:-postgresql} \
		-e HIVE_METASTORE_DB_PORT=$${POSTGRES_PORT:-5432} \
		-e HIVE_METASTORE_DB_NAME=$${POSTGRES_DB:-hive} \
		-e HIVE_METASTORE_DB_USER=$${POSTGRES_USER:-hive} \
		-e HIVE_METASTORE_DB_PASSWORD=$${POSTGRES_PASSWORD:-hive} \
		-e HIVE_WAREHOUSE_DIR=/opt/hive/warehouse \
		-e HIVE_SCRATCH_DIR=/opt/hive/scratch \
		-e HIVE_LOG_LEVEL=DEBUG \
		-e HIVE_METASTORE_URI=thrift://localhost:9083 \
		-v $(PWD)/warehouse:/opt/hive/warehouse \
		-v $(PWD)/logs:/opt/hive/logs \
		$(HIVE_IMAGE_NAME):$(HIVE_VERSION)

# Clean up everything
clean: kill-shell stop-test
	@echo "Cleanup complete." 