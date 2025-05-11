#!/bin/bash
set -euo pipefail

# Source environment variables
if [ -f ../.env ]; then
    source ../.env
fi

# Get the master pod name
MASTER_POD=$(kubectl get pods -n spark -l app.kubernetes.io/component=master -o jsonpath="{.items[0].metadata.name}")

if [ -z "$MASTER_POD" ]; then
    echo "Error: Could not find Spark master pod"
    exit 1
fi

echo "Found Spark master pod: $MASTER_POD"

# Copy test script to the pod
echo "Copying test script to pod..."
kubectl cp test_spark_cluster.py spark/$MASTER_POD:/tmp/

# Run the test
echo "Running test script..."
kubectl exec -n spark $MASTER_POD -- /opt/spark/bin/spark-submit \
    --master local[*] \
    --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" \
    --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog" \
    /tmp/test_spark_cluster.py

# Check the exit code
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed successfully!"
else
    echo "Some tests failed. Check the output above for details."
fi

exit $EXIT_CODE 