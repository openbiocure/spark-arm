# Variables
IMAGE_NAME ?= ghcr.io/openbiocure/spark-arm
IMAGE_TAG ?= v0.3
NAMESPACE ?= spark
DOCKER_BUILD_ARGS ?= --platform linux/arm64
VALUES_FILE ?= spark-arm/values.yaml

.PHONY: build push clean deploy undeploy logs test all help

# Build the Docker image
build:
	docker build $(DOCKER_BUILD_ARGS) -t $(IMAGE_NAME):$(IMAGE_TAG) -f docker/Dockerfile .

# Push the Docker image to registry
push:
	docker push $(IMAGE_NAME):$(IMAGE_TAG)

# Clean up build artifacts
clean:
	rm -rf build/

# Deploy the Spark cluster using Helm
deploy:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install spark-arm spark-arm \
		--namespace $(NAMESPACE) \
		--values $(VALUES_FILE) \
		--set image.repository=$(IMAGE_NAME) \
		--set image.tag=$(IMAGE_TAG)

# Undeploy the Spark cluster
undeploy:
	helm uninstall spark-arm --namespace $(NAMESPACE)

# Get logs from Spark pods
logs:
	kubectl logs -f -l app.kubernetes.io/name=spark-arm -n $(NAMESPACE)

# Test cluster readiness
test:
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-arm -n $(NAMESPACE) --timeout=300s

# Build, push and deploy
all: build push deploy

# Show help
help:
	@echo "Available commands:"
	@echo "  make build    - Build the Docker image"
	@echo "  make push     - Push the Docker image to registry"
	@echo "  make clean    - Clean up build artifacts"
	@echo "  make deploy   - Deploy the Spark cluster"
	@echo "  make undeploy - Undeploy the Spark cluster"
	@echo "  make logs     - Get logs from Spark pods"
	@echo "  make test     - Test cluster readiness"
	@echo "  make all      - Build, push and deploy"
	@echo "  make help     - Show this help message" 