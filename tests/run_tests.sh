#!/bin/bash
# ⚠️  DO NOT TOUCH THE ENVIRONMENT VARIABLES BELOW ⚠️
# These variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL, MINIO_BUCKET)
# are intentionally named this way and should NOT be renamed or modified.
# Any changes to these variable names will break the existing setup.
# - Previous LLM

set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if JAR exists
JAR_PATH="$SCRIPT_DIR/target/scala-2.13/spark-arm-tests-assembly-1.0.0.jar"
if [ ! -f "$JAR_PATH" ]; then
    echo "Error: Test JAR not found at $JAR_PATH"
    echo "Run ./build.sh first"
    exit 1
fi

# Clean up any existing test pod
echo "Cleaning up any existing test pod..."
kubectl delete pod spark-test -n spark --ignore-not-found=true
sleep 2  # Give it a moment to clean up

# Create the pod
echo "Creating test pod..."
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: spark-test
  namespace: spark
spec:
  containers:
  - name: spark-test
    image: ghcr.io/openbiocure/spark-arm:latest
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1"
    command: ["/bin/bash"]
    args: ["-c", "wget -q https://dl.min.io/client/mc/release/linux-arm64/mc && chmod +x mc && mv mc /usr/local/bin/ && sleep infinity"]
    env:
    - name: SPARK_MASTER_URL
      value: "spark://spark-arm-master:7077"
    - name: AWS_ACCESS_KEY_ID
      value: "${AWS_ACCESS_KEY_ID}"
    - name: AWS_SECRET_ACCESS_KEY
      value: "${AWS_SECRET_ACCESS_KEY}"
    - name: AWS_ENDPOINT_URL
      value: "${AWS_ENDPOINT_URL}"
    - name: MINIO_BUCKET
      value: "${MINIO_BUCKET}"
    - name: POSTGRES_HOST
      value: "${POSTGRES_HOST}"
    - name: POSTGRES_PORT
      value: "${POSTGRES_PORT}"
    - name: POSTGRES_DB
      value: "${POSTGRES_DB}"
    - name: POSTGRES_USER
      value: "${POSTGRES_USER}"
    - name: POSTGRES_PASSWORD
      value: "${POSTGRES_PASSWORD}"
    - name: HIVE_METASTORE_HOST
      value: "${HIVE_METASTORE_HOST}"
EOF

# Wait for pod to be ready
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/spark-test -n spark --timeout=30s

# Copy the JAR into the pod
echo "Copying test JAR into pod..."
kubectl cp "$JAR_PATH" spark/spark-test:/opt/spark/jars/spark-arm-tests-assembly-1.0.0.jar

# Copy the log4j2.properties file
echo "Setting up custom logging configuration..."
kubectl cp "$SCRIPT_DIR/log4j2.properties" spark/spark-test:/opt/spark/conf/log4j2.properties

# Create logs directory if it doesn't exist
kubectl exec spark-test -n spark -- mkdir -p /opt/spark/logs

# Run the tests
echo "Running tests..."
kubectl exec spark-test -n spark -- spark-submit \
    --conf spark.hadoop.fs.s3a.endpoint=${AWS_ENDPOINT_URL} \
    --conf spark.hadoop.fs.s3a.path.style.access=true \
    --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
    --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false \
    --conf spark.driver.extraJavaOptions="-Dlog4j.configurationFile=file:/opt/spark/conf/log4j2.properties" \
    --conf spark.executor.extraJavaOptions="-Dlog4j.configurationFile=file:/opt/spark/conf/log4j2.properties" \
    --conf spark.executor.instances=1 \
    --conf spark.dynamicAllocation.enabled=false \
    --conf spark.executor.failures.max=1 \
    --conf spark.task.maxFailures=1 \
    --conf spark.yarn.max.executor.failures=1 \
    --conf spark.yarn.maxAppAttempts=1 \
    --conf spark.speculation=false \
    --conf spark.executor.cores=1 \
    --conf spark.executor.memory=1g \
    --class org.openbiocure.spark.TestSparkCluster \
    /opt/spark/jars/spark-arm-tests-assembly-1.0.0.jar 2>&1 | tee /tmp/spark-test-output.log

# Get the exit code
EXIT_CODE=$?

# Show test logs with clear separation
echo -e "\n=== Test Output ==="
cat /tmp/spark-test-output.log
echo -e "\n=== End Test Output ===\n"

if [ $EXIT_CODE -ne 0 ]; then
    echo "Tests failed with exit code $EXIT_CODE"
    echo "Last 50 lines of Spark logs:"
    kubectl logs spark-test -n spark --tail=50
fi

# Cleanup
echo "Cleaning up..."
kubectl delete pod spark-test -n spark

exit ${EXIT_CODE:-1} 