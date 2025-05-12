#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Set error handler
trap 'handle_error ${BASH_SOURCE[0]} ${LINENO} $?' ERR

# Log environment variables
log_info "=== Starting Spark Master ==="
log_info "SPARK_HOME: $SPARK_HOME"
log_info "PATH: $PATH"
log_info "HADOOP_HOME: $HADOOP_HOME"
log_info "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

# Verify required environment variables and directories
verify_env "SPARK_HOME" "SPARK_HOME environment variable is required for master operation"
verify_dir "$SPARK_HOME" "SPARK_HOME" "Spark installation directory not found at $SPARK_HOME"

# Start the Spark master
log_info "Starting Spark master process..."
/opt/spark/sbin/start-master.sh --host $(hostname) --port 7077 --webui-port 8080

# Wait for the log file
log_info "Waiting for master log file..."
LOG_FILE=$(wait_for_file "spark--org.apache.spark.deploy.master.Master-1-*.out" 30 "Master log file not found after 30 seconds")

log_info "Found master log file: $LOG_FILE"
log_info "=== Spark Master Logs ==="

# Monitor the master process
MASTER_PID=$(pgrep -f "org.apache.spark.deploy.master.Master" || true)
if [ -n "$MASTER_PID" ]; then
    log_info "Master process started with PID: $MASTER_PID"
else
    log_error "Failed to find master process"
    exit 1
fi

# Start log monitoring
exec tail -f "$LOG_FILE" 