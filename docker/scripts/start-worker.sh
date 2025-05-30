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
    export SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT:-"8082"}
    export SPARK_WORKER_PORT=${SPARK_WORKER_PORT:-"8081"}
    export SPARK_LOCAL_DIRS=${SPARK_LOCAL_DIRS:-"/opt/spark/tmp"}

    if [[ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]]; then
    # We are inside Kubernetes
        export SPARK_WORKER_HOST=${SPARK_WORKER_HOST:-$(hostname -f)}
    else
        # We are running locally - force IPv4
        export SPARK_WORKER_HOST=${SPARK_WORKER_HOST:-$(hostname -i | awk '{print $1}')}
        # Force Java to prefer IPv4
        export SPARK_DAEMON_JAVA_OPTS="${SPARK_DAEMON_JAVA_OPTS:-} -Djava.net.preferIPv4Stack=true"
    fi

    
    log_info "Master URL: ${SPARK_MASTER_URL}"
    log_info "Worker cores: ${SPARK_WORKER_CORES}"
    log_info "Worker memory: ${SPARK_WORKER_MEMORY}"
    log_info "Worker WebUI port: ${SPARK_WORKER_WEBUI_PORT}"
    
    # Start the worker
    exec "${JAVA_HOME:-/opt/java/openjdk}/bin/java" \
        -cp "${SPARK_HOME}/conf/:${SPARK_HOME}/jars/*" \
        -Xmx1g \
        -Djava.net.preferIPv4Stack=true \
        -Dspark.worker.bindAddress=0.0.0.0 \
        -Dspark.worker.webui.bindAddress=0.0.0.0 \
        org.apache.spark.deploy.worker.Worker \
        --host "${SPARK_WORKER_HOST}" \
        --port "${SPARK_WORKER_PORT}" \
        --webui-port "${SPARK_WORKER_WEBUI_PORT}" \
        --cores "${SPARK_WORKER_CORES}" \
        --memory "${SPARK_WORKER_MEMORY}" \
        "${SPARK_MASTER_URL}"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    start_spark_worker
fi 