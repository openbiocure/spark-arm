.PHONY: shell run attach-shell kill-shell clean test stop-test build push inspect deploy undeploy status logs clean-deploy verify debug-shell k3s-shell k3s-logs

# Variables
HIVE_IMAGE_NAME ?= ghcr.io/openbiocure/hive-arm
HIVE_CONTAINER_NAME ?= hive-test
TAG ?= $(shell cat ../tag)
VERSIONS_SCRIPT ?= ../versions.sh

# Load environment variables
include ../debug.env
export

# Make help the default target
.DEFAULT_GOAL := help

# Help target
help:
	@echo "Hive Metastore Management Commands:"
	@echo ""
	@echo "Basic Operations:"
	@echo "  make build              - Build the Hive Docker image"
	@echo "  make test              - Start a test container with Hive metastore"
	@echo "  make stop-test         - Stop and remove the test container"
	@echo "  make shell             - Get an interactive shell in the container"
	@echo "  make clean             - Stop and remove test container"
	@echo ""
	@echo "Container Management:"
	@echo "  make debug-shell       - Start a clean container with just a shell (no metastore)"
	@echo "  make logs              - View container logs"
	@echo ""
	@echo "Registry Operations:"
	@echo "  make push              - Push the Docker image to registry"
	@echo ""
	@echo "Kubernetes Operations:"
	@echo "  make deploy            - Deploy Hive metastore to Kubernetes"
	@echo "  make undeploy          - Remove Hive metastore from Kubernetes"
	@echo "  make status            - Check deployment status"
	@echo "  make clean-deploy      - Remove deployment and PVCs"
	@echo "  make verify            - Verify deployment health"
	@echo "  make k3s-shell         - Get a shell in a crashed k3s pod"
	@echo "  make k3s-logs          - View logs from previous k3s container"
	@echo ""
	@echo "Environment Variables:"
	@echo "  POSTGRES_HOST          - PostgreSQL host (default: postgresql)"
	@echo "  POSTGRES_PORT          - PostgreSQL port (default: 5432)"
	@echo "  POSTGRES_DB            - Database name (default: hive)"
	@echo "  POSTGRES_USER          - Database user (default: hive)"
	@echo "  POSTGRES_PASSWORD      - Database password (default: hive)"
	@echo "  HIVE_LOG_LEVEL         - Logging level (default: DEBUG)"
	@echo ""
	@echo "For more information about each command, see the Makefile comments."

# Build the Hive Docker image
build:
	@echo "Building Hive Docker image..."
	@TAG=$$(cat ../tag); \
	BUILD_ARGS=$$(bash $(VERSIONS_SCRIPT) | grep -v '^#' | grep -v '^$$' | tr '\n' ' ' | sed 's/^ *//;s/ *$$//' | awk '{for(i=1;i<=NF;i++) printf "--build-arg %s ", $$i}'); \
	BUILD_CMD="docker build --platform linux/arm64 -t hive-arm:$$TAG $$BUILD_ARGS --build-arg IMAGE_VERSION=$$TAG -f Dockerfile ."; \
	echo "Debug: Build command: $$BUILD_CMD"; \
	eval "$$BUILD_CMD"; \
	docker tag hive-arm:$$TAG $(HIVE_IMAGE_NAME):$(TAG); \
	docker tag hive-arm:$$TAG $(HIVE_IMAGE_NAME):latest

# Push the Hive Docker image to registry
push:
	@echo "Pushing Hive Docker image..."
	@TAG=$$(cat ../tag); \
	docker tag $(HIVE_IMAGE_NAME):$(TAG) $(HIVE_IMAGE_NAME):stable; \
	docker push $(HIVE_IMAGE_NAME):$(TAG); \
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
		$(HIVE_IMAGE_NAME):$(TAG)
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
			$(HIVE_IMAGE_NAME):$(TAG); \
	fi


# Clean up everything
clean: kill-shell stop-test
	@echo "Cleanup complete." 

# Deployment targets
deploy:
	@echo "Deploying Hive metastore..."
	@echo "Checking if previous deployment exists..."
	@if kubectl get statefulset hive-metastore -n spark >/dev/null 2>&1; then \
		echo "Previous deployment found. Cleaning up..."; \
		$(MAKE) undeploy; \
	fi
	@echo "Applying Kubernetes manifests..."
	@kubectl apply -f k8s/hive-metastore.yaml -n spark
	@echo "Waiting for StatefulSet to be ready..."
	@kubectl rollout status statefulset/hive-metastore -n spark --timeout=300s
	@echo "Checking metastore service..."
	@kubectl get svc hive-metastore -n spark
	@echo "Deployment complete. Use 'make status' to check status or 'make logs' to view logs."

# Undeploy Hive metastore from Kubernetes
undeploy:
	@echo "Undeploying Hive metastore..."
	@echo "Deleting Kubernetes resources..."
	@kubectl delete -f k8s/hive-metastore.yaml -n spark --ignore-not-found=true
	@echo "Waiting for resources to be cleaned up..."
	@while kubectl get statefulset hive-metastore -n spark >/dev/null 2>&1; do \
		echo "Waiting for StatefulSet to be removed..."; \
		sleep 2; \
	done
	@echo "Cleanup complete."

# Check deployment status
status:
	@echo "Checking Hive metastore status..."
	@echo "\nStatefulSet Status:"
	@kubectl get statefulset hive-metastore -n spark
	@echo "\nPod Status:"
	@kubectl get pods -l app=hive-metastore -n spark
	@echo "\nService Status:"
	@kubectl get svc hive-metastore -n spark
	@echo "\nPVC Status:"
	@kubectl get pvc -l app=hive-metastore -n spark

# View metastore logs
logs:
	@echo "Fetching Hive metastore logs..."
	@POD=$$(kubectl get pods -l app=hive-metastore -n spark -o jsonpath='{.items[0].metadata.name}'); \
	if [ -n "$$POD" ]; then \
		kubectl logs -f $$POD -n spark; \
	else \
		echo "No metastore pod found. Is the deployment running?"; \
		exit 1; \
	fi

# Clean deployment (undeploy + remove PVCs)
clean-deploy: undeploy
	@echo "Removing persistent volume claims..."
	@kubectl delete pvc -l app=hive-metastore -n spark --ignore-not-found=true
	@echo "Clean deployment complete. All resources removed."

# Verify deployment health
verify:
	@echo "Verifying Hive metastore deployment..."
	@POD=$$(kubectl get pods -l app=hive-metastore -n spark -o jsonpath='{.items[0].metadata.name}'); \
	if [ -z "$$POD" ]; then \
		echo "No metastore pod found. Deployment may not be running."; \
		exit 1; \
	fi; \
	echo "Checking pod health..."; \
	kubectl exec $$POD -n spark -- /bin/bash -c 'ls -l /opt/hive/bin/metastore-config.sh /opt/hive/bin/start-metastore /opt/hive/bin/schematool'; \
	echo "Checking metastore service..."; \
	kubectl exec $$POD -n spark -- /bin/bash -c 'netstat -tuln | grep 9083'; \
	echo "Checking database connection..."; \
	kubectl exec $$POD -n spark -- /bin/bash -c 'echo "SELECT 1;" | PGPASSWORD=$$HIVE_METASTORE_DB_PASSWORD psql -h $$HIVE_METASTORE_DB_HOST -U $$HIVE_METASTORE_DB_USER -d $$HIVE_METASTORE_DB_NAME'

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
		$(HIVE_IMAGE_NAME):$(TAG)

# Get a debug shell in a crashed k3s pod
k3s-shell:
	@echo "Getting debug shell in crashed k3s pod..."
	@POD=$$(kubectl get pods -l app=hive-metastore -n spark -o jsonpath='{.items[0].metadata.name}'); \
	if [ -z "$$POD" ]; then \
		echo "No metastore pod found."; \
		exit 1; \
	fi; \
	echo "Found pod: $$POD"; \
	echo "Starting debug shell..."; \
	if kubectl exec -it $$POD -n spark -- /bin/bash 2>/dev/null; then \
		:; \
	else \
		echo "Container not accessible, starting persistent debug pod..."; \
		DEBUG_POD="debug-hive-$$(date +%s)"; \
		echo "Creating debug pod $$DEBUG_POD..."; \
		kubectl run $$DEBUG_POD -n spark \
			--image=ghcr.io/openbiocure/hive-arm:latest \
			--overrides='{"spec":{"volumes":[{"name":"hive-bin","emptyDir":{}}],"containers":[{"name":"debug","image":"ghcr.io/openbiocure/hive-arm:latest","command":["/bin/bash"],"args":["-c","echo '\''Debug pod started. Type exit to leave the shell.'\''; exec /bin/bash"],"volumeMounts":[{"name":"hive-bin","mountPath":"/opt/hive/bin"}],"stdin":true,"tty":true}]}}'; \
		echo "Waiting for debug pod to be ready..."; \
		if ! kubectl wait --for=condition=Ready pod/$$DEBUG_POD -n spark --timeout=30s; then \
			echo "\nDebug pod failed to start. Checking logs:"; \
			kubectl logs $$DEBUG_POD -n spark; \
			echo "\nPod events:"; \
			kubectl describe pod $$DEBUG_POD -n spark | grep -A 10 "Events:"; \
			echo "\nPod status:"; \
			kubectl get pod $$DEBUG_POD -n spark -o wide; \
			exit 1; \
		fi; \
		echo "\nDebug pod is ready! You can:"; \
		echo "1. Attach to the pod: kubectl attach -it $$DEBUG_POD -n spark"; \
		echo "2. Exec into the pod: kubectl exec -it $$DEBUG_POD -n spark -- /bin/bash"; \
		echo "3. View pod logs: kubectl logs -f $$DEBUG_POD -n spark"; \
		echo "\nThe pod will stay running until you delete it with:"; \
		echo "kubectl delete pod $$DEBUG_POD -n spark"; \
		echo "\nAttaching to pod now (type 'exit' to detach)..."; \
		kubectl attach -it $$DEBUG_POD -n spark; \
	fi

# Get logs from previous k3s container instance
k3s-logs:
	@echo "Getting logs from previous k3s container instance..."
	@POD=$$(kubectl get pods -l app=hive-metastore -n spark -o jsonpath='{.items[0].metadata.name}'); \
	if [ -z "$$POD" ]; then \
		echo "No metastore pod found."; \
		exit 1; \
	fi; \
	echo "Found pod: $$POD"; \
	echo "Previous container logs:"; \
	kubectl logs $$POD -n spark --previous