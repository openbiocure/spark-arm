#!/bin/bash

# Kill any existing port-forward processes
pkill -f "kubectl port-forward" || true

# Start port forwarding in the background
echo "Starting port forwarding..."
kubectl port-forward svc/spark-master 7077:7077 8080:8080 &
kubectl port-forward svc/minio 9000:9000 &
kubectl port-forward svc/postgresql 5432:5432 &

# Wait for ports to be ready
echo "Waiting for ports to be ready..."
sleep 5

# Check if ports are accessible
echo "Checking port availability..."
nc -z localhost 7077 || { echo "Spark master port not accessible"; exit 1; }
nc -z localhost 8080 || { echo "Spark UI port not accessible"; exit 1; }
nc -z localhost 9000 || { echo "MinIO port not accessible"; exit 1; }
nc -z localhost 5432 || { echo "PostgreSQL port not accessible"; exit 1; }

# Run the tests
echo "Running tests..."
sbt "testOnly org.openbiocure.spark.TestSparkCluster"

# Capture the test result
TEST_RESULT=$?

# Cleanup port forwarding
echo "Cleaning up port forwarding..."
pkill -f "kubectl port-forward"

# Exit with test result
exit $TEST_RESULT 