#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Set error handler
trap 'handle_error ${BASH_SOURCE[0]} ${LINENO} $?' ERR

# Function to start Spark worker
start_spark_worker() {
    log_info "Starting Spark worker..."
    
    # Validate required environment variables
    if [ -z "${SPARK_MASTER_URL:-}" ]; then
        log_error "SPARK_MASTER_URL environment variable is required"
        exit 1
    fi
    
    # Set default worker properties if not provided
    export SPARK_WORKER_CORES=${SPARK_WORKER_CORES:-"1"}
    export SPARK_WORKER_MEMORY=${SPARK_WORKER_MEMORY:-"1g"}
    export SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT:-"8081"}
    
    log_info "Master URL: ${SPARK_MASTER_URL}"
    log_info "Worker cores: ${SPARK_WORKER_CORES}"
    log_info "Worker memory: ${SPARK_WORKER_MEMORY}"
    log_info "Worker WebUI port: ${SPARK_WORKER_WEBUI_PORT}"
    
    # Start the worker
    exec ${SPARK_HOME}/sbin/start-worker.sh \
        --webui-port ${SPARK_WORKER_WEBUI_PORT} \
        --cores ${SPARK_WORKER_CORES} \
        --memory ${SPARK_WORKER_MEMORY} \
        "${SPARK_MASTER_URL}"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    start_spark_worker
fi 