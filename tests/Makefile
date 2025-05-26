.PHONY: shell run attach-shell kill-shell clean test-hive stop-test-hive

# Variables
HIVE_IMAGE_NAME ?= ghcr.io/openbiocure/hive-arm
HIVE_CONTAINER_NAME ?= hive-test
HIVE_VERSION ?= $(shell cat ../tag)

# Load environment variables
include ../debug.env
export

# Run a one-off spark command
run:
	@echo "Running spark command..."
	@kubectl cp test.scala spark/spark-arm-master-0:/tmp/
	@kubectl exec -n spark spark-arm-master-0 -- bash -c 'cd /tmp && /opt/spark/bin/spark-shell \
		--master spark://spark-arm-master:7077 \
		--driver-memory 1g \
		--executor-memory 1g \
		--conf "spark.hadoop.fs.s3a.endpoint=${AWS_ENDPOINT_URL}" \
		--conf "spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID}" \
		--conf "spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY}" \
		--conf "spark.hive.metastore.uris=thrift://spark-arm-hive:9083" \
		--conf "spark.driver.extraJavaOptions=-Djline.terminal=jline.UnsupportedTerminal" \
		< test.scala'

# Start interactive spark-shell pod
shell:
	@echo "Starting spark-shell pod..."
	@if kubectl get pod spark-shell-pod -n spark 2>/dev/null | grep -q spark-shell-pod; then \
		echo "Spark shell pod already exists. Use 'make attach-shell' to connect to it."; \
	else \
		envsubst < spark-shell-pod.yaml | kubectl apply -f - && \
		echo "Waiting for spark-shell pod to be ready..." && \
		kubectl wait --for=condition=Ready pod/spark-shell-pod -n spark --timeout=60s || \
			(echo "Pod failed to become ready. Check logs with: kubectl logs spark-shell-pod -n spark" && exit 1) && \
		echo "Spark shell pod is ready. Use 'make attach-shell' to connect to it."; \
	fi

# Attach to the spark-shell pod
attach-shell:
	@echo "Attaching to spark-shell pod..."
	@if kubectl get pod spark-shell-pod -n spark 2>/dev/null | grep -q spark-shell-pod; then \
		kubectl exec -it spark-shell-pod -n spark -- /opt/spark/bin/spark-shell \
			--master spark://spark-arm-master:7077 \
			--driver-memory 1g \
			--executor-memory 1g \
			--conf "spark.hadoop.fs.s3a.endpoint=${AWS_ENDPOINT_URL}" \
			--conf "spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID}" \
			--conf "spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY}" \
			--conf "spark.hive.metastore.uris=thrift://spark-arm-hive:9083" \
			--conf "spark.driver.extraJavaOptions=-Djline.terminal=jline.UnsupportedTerminal"; \
	else \
		echo "No spark-shell pod found. Use 'make shell' to start one." && exit 1; \
	fi

# Kill the spark-shell pod
kill-shell:
	@echo "Killing spark-shell pod..."
	@kubectl delete pod spark-shell-pod -n spark 2>/dev/null || \
		(echo "No spark-shell pod found." && exit 0)
