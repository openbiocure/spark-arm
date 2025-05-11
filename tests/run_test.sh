#!/bin/bash
set -euo pipefail

# Source environment variables
if [ -f ../.env ]; then
    source ../.env
fi

# Ensure we're in a virtual environment
if [ -z "${VIRTUAL_ENV:-}" ]; then
    echo "Error: Please activate the virtual environment first"
    echo "Run: python3 -m venv venv && source venv/bin/activate"
    exit 1
fi

# Check if port forwarding is running
if ! nc -z localhost 7077 2>/dev/null; then
    echo "Error: Spark master port (7077) is not forwarded"
    echo "Run: make port-forward"
    exit 1
fi

echo "Running Spark cluster tests locally..."
echo "Using virtual environment: $VIRTUAL_ENV"

# Run the test script directly
python3 test_spark_cluster.py

# Check the exit code
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed successfully!"
else
    echo "Some tests failed. Check the output above for details."
fi

exit $EXIT_CODE 