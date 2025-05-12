# Variables
IMAGE_NAME ?= ghcr.io/openbiocure/spark-arm
VERSION := $(shell cat tag)
IMAGE_TAG ?= $(VERSION)
NAMESPACE ?= spark
VALUES_FILE ?= spark-arm/values.yaml
ENV_FILE ?= docker/versions.env

# Load version variables
include docker/versions.env
export


.PHONY: build push clean deploy undeploy logs test test-cluster all help lint port-forward export-env opencert-init verify-urls

# Export environment variables from .env file
export-env:
	@if [ -f $(ENV_FILE) ]; then \
		echo "Exporting environment variables from $(ENV_FILE)"; \
		export $$(grep -v '^#' $(ENV_FILE) | xargs); \
	else \
		echo "Warning: $(ENV_FILE) not found"; \
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
test-cluster: export-env
	@echo "Generating test scripts in ConfigMap..."
	@./scripts/update-test-configmap.sh
	@echo "Cleaning up any existing test jobs..."
	@kubectl delete job spark-test-job -n spark --ignore-not-found=true
	@echo "Running tests in the cluster..."
	@helm upgrade --install spark-arm ./spark-arm \
		--namespace spark \
		--set test.enabled=true \
		--set minio.endpoint="${MINIO_ENDPOINT}" \
		--set minio.credentials.accessKey="${MINIO_ACCESS_KEY}" \
		--set minio.credentials.secretKey="${MINIO_SECRET_KEY}" \
		--set minio.bucket="${MINIO_BUCKET:-spark-data}" \
		--set hive.metastore.host="${POSTGRES_HOST}" \
		--set hive.metastore.port="${POSTGRES_PORT:-5432}" \
		--set hive.metastore.database="${POSTGRES_DB:-hive}" \
		--set hive.metastore.username="${POSTGRES_USER}" \
		--set hive.metastore.password="${POSTGRES_PASSWORD}"
	@echo "Waiting for test job to complete..."
	@kubectl wait --for=condition=complete job/spark-test-job -n spark --timeout=300s
	@echo "Test job logs:"
	@kubectl logs -n spark -l job-name=spark-test-job --tail=-1

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
	@echo "  make test-cluster     - Run comprehensive cluster tests"
	@echo ""
	@echo "Monitoring and Debugging:"
	@echo "  make logs             - Get logs from Spark pods"
	@echo "  make port-forward     - Forward Spark master ports (7077, 8080)"
	@echo ""
	@echo "Environment:"
	@echo "  make export-env       - Export environment variables from .env file"
	@echo ""
	@echo "For more information, see the README.md file"

