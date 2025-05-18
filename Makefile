# Variables
REGISTRY ?= ghcr.io
IMAGE_NAME ?= $(REGISTRY)/openbiocure/spark-arm
VERSION := $(shell cat tag)
IMAGE_TAG ?= $(VERSION)
NAMESPACE ?= spark
VALUES_FILE ?= spark-arm/values.yaml
VERSIONS_SCRIPT ?= docker/versions.sh

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
	BUILD_ARGS=$$(bash $(VERSIONS_SCRIPT) | awk '{printf "--build-arg %s ", $$0}'); \
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
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install spark-arm spark-arm \
		--namespace $(NAMESPACE) \
		--values $(VALUES_FILE) \
		--set image.tag=$(VERSION)

# Undeploy the Spark cluster
undeploy:
	helm uninstall spark-arm --namespace $(NAMESPACE)

# Get logs from Spark pods
logs:
	kubectl logs -f -l app.kubernetes.io/name=spark-arm -n $(NAMESPACE)

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
	@echo "Available commands:"
	@echo ""
	@echo "Build and Verification:"
	@echo "  make verify-urls      - Verify all download URLs before building"
	@echo "  make build            - Build the Docker image (includes URL verification)"
	@echo "  make push             - Push the Docker image to registry"
	@echo "  make clean            - Clean up build artifacts"
	@echo ""
	@echo "Deployment and Management:"
	@echo "  make deploy           - Deploy the Spark cluster"
	@echo "  make undeploy         - Undeploy the Spark cluster"
	@echo "  make all              - Build, push and deploy"
	@echo ""
	@echo "Monitoring and Debugging:"
	@echo "  make logs             - Get logs from Spark pods"
	@echo "  make port-forward     - Forward Spark master ports (7077, 8080)"
	@echo ""
	@echo "Environment:"
	@echo "  make export-env       - Export environment variables from versions.sh file"
	@echo ""
	@echo "For more information, see the README.md file"

