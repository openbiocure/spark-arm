# Variables
IMAGE_NAME ?= ghcr.io/openbiocure/spark-arm
VERSION := $(shell cat tag)
IMAGE_TAG ?= $(VERSION)
NAMESPACE ?= spark
DOCKER_BUILD_ARGS ?= --platform linux/arm64
VALUES_FILE ?= spark-arm/values.yaml
ENV_FILE ?= .env

.PHONY: build push clean deploy undeploy logs test test-cluster all help lint port-forward export-env opencert-init

# Export environment variables from .env file
export-env:
	@if [ -f $(ENV_FILE) ]; then \
		echo "Exporting environment variables from $(ENV_FILE)"; \
		set -a; \
		source $(ENV_FILE); \
		set +a; \
	else \
		echo "Warning: $(ENV_FILE) not found"; \
	fi

# Build the Docker image
build:
	docker build $(DOCKER_BUILD_ARGS) -t $(IMAGE_NAME):$(IMAGE_TAG) -f docker/Dockerfile .
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):latest

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

# Test cluster readiness
test:
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-arm -n $(NAMESPACE) --timeout=300s

# Run comprehensive cluster tests
test-cluster: export-env test
	@echo "Running Spark cluster tests..."
	@cd tests && ./run_test.sh

# Build, push and deploy
all: build push deploy

# Show help
help:
	@echo "Available commands:"
	@echo "  make build        - Build the Docker image"
	@echo "  make push         - Push the Docker image to registry"
	@echo "  make clean        - Clean up build artifacts"
	@echo "  make lint         - Lint Helm charts and validate templates"
	@echo "  make deploy       - Deploy the Spark cluster"
	@echo "  make undeploy     - Undeploy the Spark cluster"
	@echo "  make logs         - Get logs from Spark pods"
	@echo "  make test         - Test cluster readiness"
	@echo "  make test-cluster - Run comprehensive cluster tests"
	@echo "  make all          - Build, push and deploy"
	@echo "  make help         - Show this help message"

# Port-forward to Spark master UI (requires environment variables)
port-forward: export-env
	@echo "Forwarding Spark master UI to http://localhost:8080"
	@kubectl port-forward -n spark svc/spark-arm-master 8080:8080

# Initialize OpenCert
opencert-init:
	@echo "Initializing OpenCert"
	# Implementation of opencert-init command

# Initialize other targets
# ... existing code ... 