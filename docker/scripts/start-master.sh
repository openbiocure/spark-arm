#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Set error handler
trap 'handle_error ${BASH_SOURCE[0]} ${LINENO} $?' ERR

# Function to start Spark master
start_spark_master() {
    log_info "Starting Spark master..."
    
    # Set default master host if not provided
    export SPARK_MASTER_HOST=${SPARK_MASTER_HOST:-"0.0.0.0"}
    export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-"7077"}
    export SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT:-"8080"}
    
    log_info "Master host: ${SPARK_MASTER_HOST}"
    log_info "Master port: ${SPARK_MASTER_PORT}"
    log_info "Master WebUI port: ${SPARK_MASTER_WEBUI_PORT}"
    
    # Start the master
    exec ${SPARK_HOME}/sbin/start-master.sh \
        --host ${SPARK_MASTER_HOST} \
        --port ${SPARK_MASTER_PORT} \
        --webui-port ${SPARK_MASTER_WEBUI_PORT}
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    start_spark_master
fi 