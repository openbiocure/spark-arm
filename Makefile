.PHONY: build push shell run test test-worker stop-test stop-test-worker clean help create-network compose-up compose-down compose-logs compose-client compose-test compose-shell compose-pyspark

# Variables
SPARK_IMAGE_NAME ?= ghcr.io/openbiocure/spark-arm
SPARK_CONTAINER_NAME ?= spark-test
TAG ?= $(shell cat tag)
VERSIONS_SCRIPT ?= versions.sh

# Load environment variables
include debug.env
export

# Build the Spark Docker image
build:
	@echo "Building Spark Docker image..."
	@TAG=$$(cat tag); \
	BUILD_ARGS=$$(bash $(VERSIONS_SCRIPT) | grep -v '^#' | grep -v '^$$' | tr '\n' ' ' | sed 's/^ *//;s/ *$$//' | awk '{for(i=1;i<=NF;i++) printf "--build-arg %s ", $$i}'); \
	BUILD_CMD="docker build --platform linux/arm64 -t spark-arm:$$TAG $$BUILD_ARGS --build-arg IMAGE_VERSION=$$TAG -f docker/Dockerfile ."; \
	echo "Debug: Build command: $$BUILD_CMD"; \
	eval "$$BUILD_CMD"; \
	docker tag spark-arm:$$TAG $(SPARK_IMAGE_NAME):$(TAG); \
	docker tag spark-arm:$$TAG $(SPARK_IMAGE_NAME):latest

# Push the Spark Docker image to registry
push:
	@echo "Pushing Spark Docker image..."
	@TAG=$$(cat tag); \
	docker tag $(SPARK_IMAGE_NAME):$(TAG) $(SPARK_IMAGE_NAME):stable; \
	docker push $(SPARK_IMAGE_NAME):$(TAG); \
	docker push $(SPARK_IMAGE_NAME):latest; \
	docker push $(SPARK_IMAGE_NAME):stable

# Common directory setup for all targets
setup-dirs:
	@echo "Setting up local directories..."
	@mkdir -p $(PWD)/logs $(PWD)/master-tmp $(PWD)/worker-tmp $(PWD)/client-tmp \
		$(PWD)/master-work $(PWD)/worker-work $(PWD)/client-work $(PWD)/worker-logs
	@echo "Setting permissions for Spark directories..."
	@sudo chown -R $(shell id -u):$(shell id -g) \
		$(PWD)/logs $(PWD)/master-tmp $(PWD)/worker-tmp $(PWD)/client-tmp \
		$(PWD)/master-work $(PWD)/worker-work $(PWD)/client-work $(PWD)/worker-logs
	@sudo chmod -R 777 \
		$(PWD)/logs $(PWD)/master-tmp $(PWD)/worker-tmp $(PWD)/client-tmp \
		$(PWD)/master-work $(PWD)/worker-work $(PWD)/client-work $(PWD)/worker-logs
	@-rm -f $(PWD)/logs/spark-container.log 2>/dev/null || true
	@touch $(PWD)/logs/spark-container.log
	@sudo chown $(shell id -u):$(shell id -g) $(PWD)/logs/spark-container.log
	@chmod 644 $(PWD)/logs/spark-container.log
	@echo "Directory permissions updated."

# Modify test target
test: create-network setup-dirs
	@echo "Testing Spark container locally..."
	@echo "Loading environment variables from debug.env..."
	@echo "Creating required directories..."
	@rm -rf $(PWD)/logs $(PWD)/master-tmp
	@-mkdir -p $(PWD)/logs $(PWD)/master-tmp 2>/dev/null || true
	@chmod -R 777 $(PWD)/logs $(PWD)/master-tmp
	@echo "Stopping and removing existing container if any..."
	@docker stop $(SPARK_CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(SPARK_CONTAINER_NAME) 2>/dev/null || true
	@echo "Starting Spark container..."
	@docker run -d \
		--name $(SPARK_CONTAINER_NAME) \
		--network spark-net \
		--platform linux/arm64 \
		-p 7077:7077 \
		-p 8080:8080 \
		-e SPARK_NODE_TYPE=master \
		-e SPARK_MASTER_HOST=$(SPARK_CONTAINER_NAME) \
		-e SPARK_MASTER_PORT=7077 \
		-e SPARK_MASTER_WEBUI_PORT=8080 \
		-e SPARK_HOME=/opt/spark \
		-e HADOOP_HOME=/opt/hadoop \
		-e SPARK_LOCAL_DIRS=/opt/spark/tmp \
		-e SPARK_WORKER_DIR=/opt/spark/tmp \
		-e SPARK_DRIVER_DIR=/opt/spark/tmp \
		-e AWS_ENDPOINT_URL=$${AWS_ENDPOINT_URL} \
		-e AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID} \
		-e AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY} \
		-v $(PWD)/logs:/opt/spark/logs \
		-v $(PWD)/master-tmp:/opt/spark/tmp \
		$(SPARK_IMAGE_NAME):$(TAG)

# Modify test-worker target
test-worker: create-network setup-dirs
	@echo "Testing Spark worker container locally..."
	@echo "Loading environment variables from debug.env..."
	@echo "Creating required directories..."
	@rm -rf $(PWD)/worker-logs $(PWD)/worker-tmp
	@-mkdir -p $(PWD)/worker-logs $(PWD)/worker-tmp 2>/dev/null || true
	@chmod -R 777 $(PWD)/worker-logs $(PWD)/worker-tmp
	@echo "Starting Spark worker container..."
	@docker run -d \
		--name $(SPARK_CONTAINER_NAME)-worker \
		--network spark-net \
		--platform linux/arm64 \
		-p 8081:8081 \
		-e SPARK_NODE_TYPE=worker \
		-e SPARK_MASTER_URL=spark://$(SPARK_CONTAINER_NAME):7077 \
		-e SPARK_WORKER_MEMORY=3G \
		-e SPARK_WORKER_CORES=2 \
		-e SPARK_LOCAL_DIRS=/opt/spark/tmp \
		-e SPARK_WORKER_DIR=/opt/spark/tmp \
		-e SPARK_DRIVER_DIR=/opt/spark/tmp \
		-e AWS_ENDPOINT_URL=$${AWS_ENDPOINT_URL} \
		-e AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID} \
		-e AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY} \
		-v $(PWD)/worker-logs:/opt/spark/logs \
		-v $(PWD)/worker-tmp:/opt/spark/tmp \
		$(SPARK_IMAGE_NAME):$(TAG)

# Stop and remove test container
stop-test:
	@echo "Stopping and removing test container..."
	@docker stop $(SPARK_CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(SPARK_CONTAINER_NAME) 2>/dev/null || true

# Stop and remove worker test container
stop-test-worker:
	@echo "Stopping and removing worker test container..."
	@docker stop $(SPARK_CONTAINER_NAME)-worker 2>/dev/null || true
	@docker rm $(SPARK_CONTAINER_NAME)-worker 2>/dev/null || true

# Modify shell target
shell: setup-dirs
	@if docker ps -q -f name=$(SPARK_CONTAINER_NAME) | grep -q .; then \
		echo "Container is running, connecting to it..."; \
		docker exec -it $(SPARK_CONTAINER_NAME) /bin/bash; \
	else \
		echo "Container is not running, starting a new one..."; \
		docker stop $(SPARK_CONTAINER_NAME) 2>/dev/null || true; \
		docker rm $(SPARK_CONTAINER_NAME) 2>/dev/null || true; \
		docker run -it \
			--name $(SPARK_CONTAINER_NAME) \
			--network spark-net \
			--platform linux/arm64 \
			--entrypoint /bin/bash \
			-e SPARK_NODE_TYPE=master \
			-e SPARK_LOCAL_DIRS=/opt/spark/tmp \
			-e SPARK_WORKER_DIR=/opt/spark/tmp \
			-e SPARK_DRIVER_DIR=/opt/spark/tmp \
			-e AWS_ENDPOINT_URL=$${AWS_ENDPOINT_URL} \
			-e AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID} \
			-e AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY} \
			-v $(PWD)/logs:/opt/spark/logs \
			-v $(PWD)/master-tmp:/opt/spark/tmp \
			$(SPARK_IMAGE_NAME):$(TAG); \
	fi

# Modify shell-worker target
shell-worker: setup-dirs
	@if docker ps -q -f name=$(SPARK_CONTAINER_NAME)-worker | grep -q .; then \
		echo "Worker container is running, connecting to it..."; \
		docker exec -it $(SPARK_CONTAINER_NAME)-worker /bin/bash; \
	else \
		echo "Worker container is not running, starting a new one..."; \
		docker stop $(SPARK_CONTAINER_NAME)-worker 2>/dev/null || true; \
		docker rm $(SPARK_CONTAINER_NAME)-worker 2>/dev/null || true; \
		docker run -it \
			--name $(SPARK_CONTAINER_NAME)-worker \
			--network spark-net \
			--platform linux/arm64 \
			--entrypoint /bin/bash \
			-e SPARK_NODE_TYPE=worker \
			-e SPARK_MASTER_URL=spark://$(SPARK_CONTAINER_NAME):7077 \
			-e SPARK_WORKER_MEMORY=3G \
			-e SPARK_WORKER_CORES=2 \
			-e SPARK_LOCAL_DIRS=/opt/spark/tmp \
			-e SPARK_WORKER_DIR=/opt/spark/tmp \
			-e SPARK_DRIVER_DIR=/opt/spark/tmp \
			-e AWS_ENDPOINT_URL=$${AWS_ENDPOINT_URL} \
			-e AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID} \
			-e AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY} \
			-v $(PWD)/worker-logs:/opt/spark/logs \
			-v $(PWD)/worker-tmp:/opt/spark/tmp \
			$(SPARK_IMAGE_NAME):$(TAG); \
	fi

# Clean up everything
clean: stop-test stop-test-worker
	@echo "Cleaning up Docker resources..."
	@docker network rm spark-net 2>/dev/null || true
	docker rmi $(SPARK_IMAGE_NAME):$(TAG) 2>/dev/null || true
	docker rmi $(SPARK_IMAGE_NAME):latest 2>/dev/null || true
	docker rmi $(SPARK_IMAGE_NAME):stable 2>/dev/null || true
	@echo "Cleanup complete."

# Create Docker network
create-network:
	@echo "Creating Docker network if it doesn't exist..."
	@docker network create spark-net || true

# Modify client target
client: setup-dirs
	@echo "Starting Spark shell client..."
	docker run -it --network spark-net \
		-v $(PWD):/opt/spark/work \
		-v $(PWD)/client-tmp:/opt/spark/tmp \
		-e SPARK_MASTER_URL=spark://spark-test:7077 \
		-e SPARK_MASTER=spark://spark-test:7077 \
		-e SPARK_HOME=/opt/spark \
		-e SPARK_CLASSPATH=/opt/spark/jars/* \
		-e SPARK_BUILD_DIR=/opt/spark \
		-e SPARK_SCALA_VERSION=2.13 \
		-e SPARK_LOCAL_DIRS=/opt/spark/tmp \
		-e SPARK_WORKER_DIR=/opt/spark/tmp \
		-e SPARK_DRIVER_DIR=/opt/spark/tmp \
		ghcr.io/openbiocure/spark-arm:v0.6.2 \
		/opt/spark/bin/run-example \
		--master spark://spark-test:7077 \
		--conf spark.driver.port=4040 \
		--conf spark.driver.host=spark-client \
		--conf spark.driver.bindAddress=0.0.0.0 \
		--conf spark.blockManager.port=4041 \
		--conf spark.local.dir=/opt/spark/tmp \
		--executor-memory 512m \
		--total-executor-cores 1 \
		SparkPi 10

# Docker Compose targets
compose-up: setup-dirs
	@echo "Starting Spark cluster with docker compose..."
	@docker compose up -d
	@echo "Cluster started. Access points:"
	@echo "  - Master UI: http://localhost:8080"
	@echo "  - Worker UI: http://localhost:8082"
	@echo "  - Master URL: spark://spark-test:7077"
	@echo "Available commands:"
	@echo "  - make compose-shell    # Start Spark shell"
	@echo "  - make compose-pyspark  # Start PySpark"
	@echo "  - make compose-test     # Run SparkPi example"
	@echo "  - make compose-client   # Get a bash shell"

compose-down:
	@echo "Stopping Spark cluster..."
	@docker compose down -v
	@echo "Cleaning up local directories..."
	@rm -rf $(PWD)/logs $(PWD)/master-tmp $(PWD)/worker-tmp $(PWD)/client-tmp $(PWD)/worker-logs
	@echo "Cluster stopped and cleaned up."

compose-logs:
	@docker compose logs -f

compose-client:
	@echo "Connecting to Spark client container..."
	@echo "Note: Use 'exit' to leave the container shell"
	@docker compose exec spark-client /bin/bash

compose-test:
	@echo "Running SparkPi example..."
	@docker compose exec spark-client /opt/spark/bin/run-example \
		--master spark://spark-test:7077 \
		--conf spark.driver.port=4040 \
		--conf spark.driver.host=spark-test-client \
		--conf spark.driver.bindAddress=0.0.0.0 \
		--conf spark.blockManager.port=4041 \
		--conf spark.local.dir=/opt/spark/tmp \
		--executor-memory 512m \
		--total-executor-cores 1 \
		SparkPi 10

compose-shell:
	@echo "Starting Spark shell..."
	@docker compose exec spark-client /opt/spark/bin/spark-shell \
		--master spark://spark-test:7077 \
		--driver-memory 512m \
		--executor-memory 512m \
		--total-executor-cores 1 \
		--conf spark.driver.port=4040 \
		--conf spark.driver.host=spark-test-client \
		--conf spark.driver.bindAddress=0.0.0.0 \
		--conf spark.blockManager.port=4041 \
		--conf spark.local.dir=/opt/spark/tmp \
		--conf spark.network.timeout=600s \
		--conf spark.executor.heartbeatInterval=60s \
		--conf spark.dynamicAllocation.enabled=false \
		--conf spark.shuffle.service.enabled=false

compose-pyspark:
	@echo "Starting PySpark..."
	@docker compose exec spark-client /opt/spark/bin/pyspark \
		--master spark://spark-test:7077 \
		--conf spark.driver.port=4040 \
		--conf spark.driver.host=spark-test-client \
		--conf spark.driver.bindAddress=0.0.0.0 \
		--conf spark.blockManager.port=4041 \
		--conf spark.local.dir=/opt/spark/tmp

# Help target
help:
	@echo "Available targets:"
	@echo "  build          - Build the spark-arm Docker image"
	@echo "  push           - Push the spark-arm Docker image to registry"
	@echo "  test           - Test Spark master container locally"
	@echo "  test-worker    - Test Spark worker container locally"
	@echo "  stop-test      - Stop and remove master test container"
	@echo "  stop-test-worker - Stop and remove worker test container"
	@echo "  shell          - Get a shell in the master container"
	@echo "  shell-worker   - Get a shell in the worker container"
	@echo "  clean          - Clean up all resources"
	@echo "  compose-up     - Start Spark cluster using docker compose"
	@echo "  compose-down   - Stop Spark cluster and clean up"
	@echo "  compose-logs   - View logs from all containers"
	@echo "  compose-client - Get a shell in the client container"
	@echo "  compose-shell  - Start Spark shell"
	@echo "  compose-pyspark - Start PySpark"
	@echo "  compose-test   - Run SparkPi example in the cluster"
	@echo ""
	@echo "Variables:"
	@echo "  SPARK_IMAGE_NAME    - Docker image name (default: ghcr.io/openbiocure/spark-arm)"
	@echo "  SPARK_CONTAINER_NAME - Container name for local testing (default: spark-test)"
	@echo "  TAG                 - Image version (default: from tag)"
	@echo "  VERSIONS_SCRIPT     - Script to get build arguments (default: versions.sh)"