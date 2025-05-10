# Variables
IMAGE_NAME = ghcr.io/openbiocure/spark-arm
IMAGE_TAG = v0.3
NAMESPACE = spark

# Docker build arguments
DOCKER_BUILD_ARGS = --platform linux/arm64

# Helm values file
VALUES_FILE = spark-arm/values.yaml

.PHONY: build push clean deploy undeploy test logs

# Build the Docker image
build:
	docker build $(DOCKER_BUILD_ARGS) -t $(IMAGE_NAME):$(IMAGE_TAG) -f docker/Dockerfile .

# Push the Docker image to registry
push:
	docker push $(IMAGE_NAME):$(IMAGE_TAG)

# Clean up build artifacts
clean:
	rm -rf docker/scripts/*.sh
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

# Deploy the Spark cluster using Helm
deploy:
	helm upgrade --install spark-arm ./spark-arm \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--values $(VALUES_FILE)

# Undeploy the Spark cluster
undeploy:
	helm uninstall spark-arm --namespace $(NAMESPACE)

# Get logs from Spark pods
logs:
	kubectl logs -f -l app.kubernetes.io/component=master -n $(NAMESPACE) & \
	kubectl logs -f -l app.kubernetes.io/component=worker -n $(NAMESPACE)

# Test the Spark cluster
test:
	@echo "Testing Spark cluster..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=master -n $(NAMESPACE) --timeout=300s
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=worker -n $(NAMESPACE) --timeout=300s
	@echo "Spark cluster is ready!"

# Build and deploy in one command
all: build push deploy

# Help command
help:
	@echo "Available commands:"
	@echo "  make build     - Build the Docker image"
	@echo "  make push      - Push the Docker image to registry"
	@echo "  make clean     - Clean up build artifacts"
	@echo "  make deploy    - Deploy the Spark cluster using Helm"
	@echo "  make undeploy  - Undeploy the Spark cluster"
	@echo "  make logs      - Get logs from Spark pods"
	@echo "  make test      - Test the Spark cluster"
	@echo "  make all       - Build, push and deploy in one command"
	@echo "  make help      - Show this help message" 