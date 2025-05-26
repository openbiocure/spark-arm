#!/bin/bash

# Function to check if metastore has started successfully
check_metastore_startup() {
    local metastore_pid=$1
    local max_attempts=${2:-30}  # Default to 30 attempts if not specified
    local attempt=1

    echo "Waiting for metastore to start..."
    while [ $attempt -le $max_attempts ]; do
        if lsof -i :9083 -sTCP:LISTEN >/dev/null 2>&1; then
            echo "Metastore started successfully on port 9083"
            return 0
        fi
        
        # Check if process is still running
        if ! kill -0 $metastore_pid >/dev/null 2>&1; then
            echo "Error: Metastore process died. Check logs:"
            echo "----------------------------------------"
            echo "Contents of ${HIVE_HOME}/logs/hive.log:"
            cat ${HIVE_HOME}/logs/hive.log
            echo "----------------------------------------"
            echo "Contents of ${HIVE_HOME}/logs/metastore.out:"
            cat ${HIVE_HOME}/logs/metastore.out
            echo "----------------------------------------"
            return 1
        fi
        
        echo "Waiting for metastore to start... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "Error: Metastore failed to start within $max_attempts attempts"
    echo "Last few lines of logs:"
    echo "----------------------------------------"
    echo "Contents of ${HIVE_HOME}/logs/hive.log:"
    tail -n 20 ${HIVE_HOME}/logs/hive.log
    echo "----------------------------------------"
    echo "Contents of ${HIVE_HOME}/logs/metastore.out:"
    tail -n 20 ${HIVE_HOME}/logs/metastore.out
    echo "----------------------------------------"
    return 1
} 