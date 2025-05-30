#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Set error handler
trap 'handle_error ${BASH_SOURCE[0]} ${LINENO} $?' ERR

# Determine node type from environment variable
NODE_TYPE=${SPARK_NODE_TYPE:-"master"}

log_info "Starting node as: $NODE_TYPE"

case $NODE_TYPE in
    "master")
        exec /opt/spark/scripts/start-master.sh
        ;;
    "worker")
        exec /opt/spark/scripts/start-worker.sh
        ;;
    "hive")
        log_info "Starting Hive Server2..."
        exec ${HIVE_HOME}/bin/hiveserver2
        ;;
    *)
        log_error "Invalid node type: $NODE_TYPE. Must be either 'master', 'worker', or 'hive'"
        exit 1
        ;;
esac 