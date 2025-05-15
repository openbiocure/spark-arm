# Variables
REGISTRY ?= ghcr.io
IMAGE_NAME ?= $(REGISTRY)/openbiocure/spark-arm
VERSION := $(shell cat tag)
IMAGE_TAG ?= $(VERSION)
NAMESPACE ?= spark
VALUES_FILE ?= spark-arm/values.yaml
VERSIONS_ENV_FILE ?= docker/versions.env
ENV_FILE ?= .env

# Load version variables
include $(VERSIONS_ENV_FILE)
export


.PHONY: build push clean deploy undeploy logs test test-cluster test-local all help lint port-forward export-env opencert-init verify-urls

# Export environment variables from both .env files
export-env:
	@if [ -f $(ENV_FILE) ]; then \
		echo "Exporting environment variables from $(ENV_FILE)"; \
		export $$(grep -v '^#' $(ENV_FILE) | xargs); \
	else \
		echo "Warning: $(ENV_FILE) not found"; \
	fi
	@if [ -f $(VERSIONS_ENV_FILE) ]; then \
		echo "Exporting environment variables from $(VERSIONS_ENV_FILE)"; \
		export $$(grep -v '^#' $(VERSIONS_ENV_FILE) | xargs); \
	else \
		echo "Warning: $(VERSIONS_ENV_FILE) not found"; \
	fi

# Build the Docker image
build: verify-urls
	@echo "Building Docker image..."
	@TAG=$$(cat tag); \
	ARGS=""; \
	set -a; . docker/versions.env; set +a; \
	while IFS='=' read -r key val; do \
		case $$key in \
			\#*|'') continue ;; \
			*) val=$$(eval echo $$val); ARGS="$$ARGS --build-arg $$key=$$val" ;; \
		esac; \
	done < docker/versions.env; \
	echo docker build --platform linux/arm64 -t spark-arm:$$TAG $$ARGS -f docker/Dockerfile .; \
	docker build --platform linux/arm64 -t spark-arm:$$TAG $$ARGS -f docker/Dockerfile .; \
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

# Test cluster readiness
test:
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-arm -n $(NAMESPACE) --timeout=300s

# Run comprehensive cluster tests
test-cluster:
	@chmod +x tests/run_tests.sh
	@set -a; . debug.env; set +a; \
	export $$(grep -v '^#' .env | cut -d= -f1); \
	./tests/run_tests.sh

# Run tests locally with port forwarding
test-local: export-env
	@echo "Building tests..."
	@cd tests && sbt clean assembly
	@echo "Setting up port forwarding for Spark master..."
	@kubectl port-forward -n spark svc/spark-arm-master 7077:7077 8080:8080 & echo $$! > .port-forward.pid
	@echo "Waiting for ports to be ready..."
	@sleep 5
	@echo "Running local tests..."
	@cd tests && set -a; . ../debug.env; set +a; \
		SPARK_MASTER_URL="local[*]" spark-submit \
		--class org.openbiocure.spark.TestSparkCluster \
		target/scala-2.12/spark-arm-tests-assembly-1.0.0.jar || (cd .. && kill $$(cat .port-forward.pid) 2>/dev/null; rm -f .port-forward.pid; exit 1)
	@echo "Cleaning up port forwarding..."
	@kill $$(cat .port-forward.pid) 2>/dev/null || true
	@rm -f .port-forward.pid

# Build, push and deploy
all: build push deploy

# Port-forward to Spark master UI (requires environment variables)
port-forward: export-env
	@echo "Forwarding Spark master ports:"
	@echo "- Master: localhost:7077"
	@echo "- UI: http://localhost:8080"
	@kubectl port-forward -n spark svc/spark-arm-master 7077:7077 8080:8080

# Verify URLs
verify-urls: export-env
	@echo "Verifying download URLs..."
	@chmod +x docker/scripts/verify-urls.sh
	@./docker/scripts/verify-urls.sh

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
	@echo "Testing and Validation:"
	@echo "  make lint             - Lint Helm charts and validate templates"
	@echo "  make test             - Test cluster readiness"
	@echo "  make test-local       - Run tests locally with port forwarding"
	@echo "  make test-cluster     - Run comprehensive cluster tests in pod"
	@echo ""
	@echo "Monitoring and Debugging:"
	@echo "  make logs             - Get logs from Spark pods"
	@echo "  make port-forward     - Forward Spark master ports (7077, 8080)"
	@echo ""
	@echo "Environment:"
	@echo "  make export-env       - Export environment variables from .env file"
	@echo ""
	@echo "For more information, see the README.md file"

