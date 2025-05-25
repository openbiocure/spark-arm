# Variables
REGISTRY ?= ghcr.io
IMAGE_NAME ?= $(REGISTRY)/openbiocure/spark-arm
HIVE_IMAGE_NAME ?= $(REGISTRY)/openbiocure/hive-arm
VERSION := $(shell cat tag)
IMAGE_TAG ?= $(VERSION)
NAMESPACE ?= spark
VALUES_FILE ?= spark-arm/values.yaml
VERSIONS_SCRIPT ?= versions.sh
MASTER_POD ?= spark-arm-master-0

.PHONY: build push clean lint deploy undeploy logs build-hive push-hive all port-forward copy-test-files help

# Export environment variables from versions.sh
export-env:
	@if [ -f $(VERSIONS_SCRIPT) ]; then \
		echo "Exporting environment variables from $(VERSIONS_SCRIPT)"; \
		eval $$(bash $(VERSIONS_SCRIPT)); \
	else \
		echo "Error: $(VERSIONS_SCRIPT) not found"; \
		exit 1; \
	fi

# Verify URLs before building
verify-urls: export-env
	@echo "URL verification will be performed during Docker build"
	@echo "Skipping pre-build verification as it's handled in the Dockerfile"

# Build the Docker image
build: verify-urls
	@echo "Building Docker image..."
	@TAG=$$(cat tag); \
	BUILD_ARGS=$$(bash $(VERSIONS_SCRIPT) | grep -v '^#' | grep -v '^$$' | tr '\n' ' ' | sed 's/^ *//;s/ *$$//' | awk '{for(i=1;i<=NF;i++) printf "--build-arg %s ", $$i}'); \
	BUILD_CMD="docker build --platform linux/arm64 -t spark-arm:$$TAG $$BUILD_ARGS -f docker/Dockerfile ."; \
	echo "Debug: Build command: $$BUILD_CMD"; \
	eval "$$BUILD_CMD"; \
	docker tag spark-arm:$$TAG $(IMAGE_NAME):$(IMAGE_TAG); \
	docker tag spark-arm:$$TAG $(IMAGE_NAME):latest

# Push the Docker image to registry
push:
	docker push $(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(IMAGE_NAME):latest

# Clean up build artifacts
clean:
	rm -rf build/

# Lint Helm charts
lint:
	helm lint spark-arm
	helm template spark-arm spark-arm --values $(VALUES_FILE)

# Deploy the Spark cluster using Helm
deploy: export-env lint
	@echo "Loading environment variables from debug.env..."
	@if [ -f debug.env ]; then \
		MINIO_ACCESS_KEY=$$(grep AWS_ACCESS_KEY_ID debug.env | cut -d '=' -f2); \
		MINIO_SECRET_KEY=$$(grep AWS_SECRET_ACCESS_KEY debug.env | cut -d '=' -f2); \
		MINIO_ENDPOINT=$$(grep AWS_ENDPOINT_URL debug.env | cut -d '=' -f2); \
		MINIO_BUCKET=$$(grep MINIO_BUCKET debug.env | cut -d '=' -f2); \
		POSTGRES_HOST=$$(grep POSTGRES_HOST debug.env | cut -d '=' -f2); \
		POSTGRES_PORT=$$(grep POSTGRES_PORT debug.env | cut -d '=' -f2); \
		POSTGRES_DB=$$(grep POSTGRES_DB debug.env | cut -d '=' -f2); \
		POSTGRES_USER=$$(grep POSTGRES_USER debug.env | cut -d '=' -f2); \
		POSTGRES_PASSWORD=$$(grep POSTGRES_PASSWORD debug.env | cut -d '=' -f2); \
		TAG=$$(cat tag); \
		kubectl create namespace spark --dry-run=client -o yaml | kubectl apply -f -; \
		MINIO_ACCESS_KEY=$$MINIO_ACCESS_KEY MINIO_SECRET_KEY=$$MINIO_SECRET_KEY MINIO_ENDPOINT=$$MINIO_ENDPOINT MINIO_BUCKET=$$MINIO_BUCKET POSTGRES_HOST=$$POSTGRES_HOST POSTGRES_PORT=$$POSTGRES_PORT POSTGRES_DB=$$POSTGRES_DB POSTGRES_USER=$$POSTGRES_USER POSTGRES_PASSWORD=$$POSTGRES_PASSWORD \
		helm upgrade --install spark-arm spark-arm \
			--namespace spark \
			--values spark-arm/values.yaml \
			--set image.tag=$$TAG \
			--set hive.image.tag=$$TAG \
			--set hive.metastore.db.host=$${POSTGRES_HOST:-postgresql} \
			--set hive.metastore.db.port=$${POSTGRES_PORT:-5432} \
			--set hive.metastore.db.name=$${POSTGRES_DB:-hive} \
			--set hive.metastore.db.user=$${POSTGRES_USER:-hive} \
			--set hive.metastore.db.password=$${POSTGRES_PASSWORD:-hive} \
			--set minio.endpoint=$${MINIO_ENDPOINT:-http://minio:9000} \
			--set minio.bucket=$${MINIO_BUCKET:-spark-data} \
			--set minio.credentials.accessKey=$${MINIO_ACCESS_KEY} \
			--set minio.credentials.secretKey=$${MINIO_SECRET_KEY}; \
	else \
		echo "Error: debug.env file not found"; \
		exit 1; \
	fi

# Undeploy the Spark cluster
undeploy:
	helm uninstall spark-arm --namespace $(NAMESPACE)

# Get logs from Spark pods
logs:
	kubectl logs -f -l app.kubernetes.io/name=spark-arm -n $(NAMESPACE)

# Build the Hive Docker image
build-hive: verify-urls
	@echo "Building Hive Docker image..."
	@TAG=$$(cat tag); \
	BUILD_ARGS=$$(bash $(VERSIONS_SCRIPT) | grep -v '^#' | grep -v '^$$' | tr '\n' ' ' | sed 's/^ *//;s/ *$$//' | awk '{for(i=1;i<=NF;i++) printf "--build-arg %s ", $$i}'); \
	BUILD_CMD="docker build --platform linux/arm64 -t hive-arm:$$TAG $$BUILD_ARGS --build-arg IMAGE_VERSION=$$TAG -f hive/Dockerfile hive"; \
	echo "Debug: Build command: $$BUILD_CMD"; \
	eval "$$BUILD_CMD"; \
	docker tag hive-arm:$$TAG $(HIVE_IMAGE_NAME):$(IMAGE_TAG); \
	docker tag hive-arm:$$TAG $(HIVE_IMAGE_NAME):latest

# Push the Hive Docker image to registry
push-hive:
	docker tag $(HIVE_IMAGE_NAME):$(IMAGE_TAG) $(HIVE_IMAGE_NAME):stable
	docker push $(HIVE_IMAGE_NAME):$(IMAGE_TAG)
	docker push $(HIVE_IMAGE_NAME):latest
	docker push $(HIVE_IMAGE_NAME):stable

# Build, push and deploy
all: build push deploy

# Port-forward to Spark master UI (requires environment variables)
port-forward: export-env
	@echo "Forwarding Spark master ports:"
	@echo "- Master: localhost:7077"
	@echo "- UI: http://localhost:8080"
	@kubectl port-forward -n spark svc/spark-arm-master 7077:7077 8080:8080

# Show help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk -F ':|##' '/^[^\t].+?:.*?##/ { printf "  %-20s %s\n", $$1, $$NF }' $(MAKEFILE_LIST)

