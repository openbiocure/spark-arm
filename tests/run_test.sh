#!/bin/bash
set -euo pipefail

# Source environment variables
if [ -f ../.env ]; then
    source ../.env
fi

# Check if port forwarding is running
if ! nc -z localhost 7077 2>/dev/null; then
    echo "Error: Spark master port (7077) is not forwarded"
    echo "Run: make port-forward"
    exit 1
fi

echo "Running Spark cluster tests locally..."

# Build the Scala project
echo "Building Scala project..."
cd "$(dirname "$0")"
sbt clean assembly

# Run the test script
echo "Running tests..."
spark-submit \
  --class org.openbiocure.spark.TestSparkCluster \
  target/scala-2.13/spark-arm-tests-assembly-1.0.0.jar

# Check the exit code
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed successfully!"
else
    echo "Some tests failed. Check the output above for details."
fi

exit $EXIT_CODE 