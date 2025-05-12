#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Set error handler
trap 'handle_error ${BASH_SOURCE[0]} ${LINENO} $?' ERR

# Log environment variables
log_info "=== Starting Spark Worker ==="
log_info "SPARK_HOME: $SPARK_HOME"
log_info "PATH: $PATH"
log_info "HADOOP_HOME: $HADOOP_HOME"
log_info "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
log_info "SPARK_MASTER_HOST: $SPARK_MASTER_HOST"
log_info "SPARK_MASTER_PORT: $SPARK_MASTER_PORT"
log_info "SPARK_WORKER_CORES: $SPARK_WORKER_CORES"
log_info "SPARK_WORKER_MEMORY: $SPARK_WORKER_MEMORY"

# Verify required environment variables
verify_env "SPARK_HOME" "SPARK_HOME environment variable is required for worker operation"
verify_env "SPARK_MASTER_HOST" "SPARK_MASTER_HOST environment variable is required for worker operation"
verify_env "SPARK_MASTER_PORT" "SPARK_MASTER_PORT environment variable is required for worker operation"
verify_env "SPARK_WORKER_CORES" "SPARK_WORKER_CORES environment variable is required for worker operation"
verify_env "SPARK_WORKER_MEMORY" "SPARK_WORKER_MEMORY environment variable is required for worker operation"

# Verify required directories
verify_dir "$SPARK_HOME" "SPARK_HOME" "Spark installation directory not found at $SPARK_HOME"

# Verify master is reachable
log_info "Verifying master connectivity..."
if ! nc -z $SPARK_MASTER_HOST $SPARK_MASTER_PORT; then
    log_error "Cannot connect to master at $SPARK_MASTER_HOST:$SPARK_MASTER_PORT"
    exit 1
fi
log_info "Master is reachable"

# Start the Spark worker
log_info "Starting Spark worker process..."
/opt/spark/sbin/start-worker.sh spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT} \
    --cores $SPARK_WORKER_CORES \
    --memory $SPARK_WORKER_MEMORY

# Wait for the log file
log_info "Waiting for worker log file..."
LOG_FILE=$(wait_for_file "spark--org.apache.spark.deploy.worker.Worker-*.out" 30 "Worker log file not found after 30 seconds")

log_info "Found worker log file: $LOG_FILE"
log_info "=== Spark Worker Logs ==="

# Monitor the worker process
WORKER_PID=$(pgrep -f "org.apache.spark.deploy.worker.Worker" || true)
if [ -n "$WORKER_PID" ]; then
    log_info "Worker process started with PID: $WORKER_PID"
else
    log_error "Failed to find worker process"
    exit 1
fi

# Start log monitoring
exec tail -f "$LOG_FILE" 