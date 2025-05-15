#!/bin/bash
set -euo pipefail

# Parse command line arguments
FORCE_BUILD=false
for arg in "$@"; do
    case $arg in
        --force)
            FORCE_BUILD=true
            shift
            ;;
    esac
done

# Build the JAR if needed
JAR_PATH="target/scala-2.13/spark-arm-tests-assembly-1.0.0.jar"
cd "$(dirname "$0")"

if [ "$FORCE_BUILD" = true ] || [ ! -f "$JAR_PATH" ]; then
    echo "Building test JAR..."
    sbt clean assembly
fi

if [ ! -f "$JAR_PATH" ]; then
    echo "Error: Test JAR not found at $JAR_PATH"
    exit 1
fi

echo "Test JAR is ready at $JAR_PATH"
exit 0 