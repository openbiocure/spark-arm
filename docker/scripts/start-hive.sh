#!/bin/bash

# Source logging functions
source /opt/spark/scripts/logging.sh

# Set script name for logging
SCRIPT_NAME="start-hive.sh"

# Log start
log_info "Starting Hive Server2..."

# Check required environment variables
required_vars=(
    "HIVE_METASTORE_HOST"
    "HIVE_METASTORE_PORT"
    "HIVE_METASTORE_USER"
    "HIVE_METASTORE_PASSWORD"
    "HIVE_SERVER2_HOST"
    "HIVE_SERVER2_PORT"
    "HIVE_WAREHOUSE_DIR"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Export Hive environment variables
export HIVE_HOME=/opt/hive
export PATH=$HIVE_HOME/bin:$PATH

# Initialize Hive metastore if needed
if [ ! -f /opt/hive/metastore/initialized ]; then
    log_info "Initializing Hive metastore..."
    
    # Create metastore directory
    mkdir -p /opt/hive/metastore
    
    # Initialize schema
    schematool -initSchema -dbType postgres \
        -url "jdbc:postgresql://${HIVE_METASTORE_HOST}:${HIVE_METASTORE_PORT}/hive" \
        -user "${HIVE_METASTORE_USER}" \
        -passWord "${HIVE_METASTORE_PASSWORD}"
    
    if [ $? -eq 0 ]; then
        touch /opt/hive/metastore/initialized
        log_info "Hive metastore initialized successfully"
    else
        log_error "Failed to initialize Hive metastore"
        exit 1
    fi
else
    log_info "Hive metastore already initialized"
fi

# Start HiveServer2
log_info "Starting HiveServer2 on ${HIVE_SERVER2_HOST}:${HIVE_SERVER2_PORT}..."
hiveserver2 \
    --hiveconf hive.metastore.uris="thrift://${HIVE_METASTORE_HOST}:${HIVE_METASTORE_PORT}" \
    --hiveconf hive.metastore.warehouse.dir="${HIVE_WAREHOUSE_DIR}" \
    --hiveconf hive.server2.thrift.bind.host="${HIVE_SERVER2_HOST}" \
    --hiveconf hive.server2.thrift.port="${HIVE_SERVER2_PORT}" \
    --hiveconf hive.server2.authentication=NONE \
    --hiveconf hive.server2.enable.doAs=false

# Log exit
log_info "HiveServer2 stopped"
exit $? 