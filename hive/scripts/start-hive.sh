#!/bin/bash

set -e

# Source logging functions
source "$(dirname "$0")/logging.sh"

# Function to check if a port is in use
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# Function to wait for a service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local max_attempts=30
    local attempt=1

    log_info "Waiting for $service to be ready on $host:$port..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" >/dev/null 2>&1; then
            log_info "$service is ready!"
            return 0
        fi
        log_info "Attempt $attempt/$max_attempts: $service not ready yet, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "$service failed to start after $max_attempts attempts"
    return 1
}

# Start Hive Metastore
start_metastore() {
    if ! check_port 9083; then
        log_info "Starting Hive Metastore..."
        nohup hive --service metastore > "${HIVE_HOME}/logs/metastore.log" 2>&1 &
        wait_for_service localhost 9083 "Hive Metastore"
    else
        log_info "Hive Metastore is already running"
    fi
}

# Start HiveServer2
start_hiveserver2() {
    if ! check_port 10000; then
        log_info "Starting HiveServer2..."
        nohup hive --service hiveserver2 > "${HIVE_HOME}/logs/hiveserver2.log" 2>&1 &
        wait_for_service localhost 10000 "HiveServer2"
    else
        log_info "HiveServer2 is already running"
    fi
}

# Main execution
log_info "Starting Hive services..."

# Start Metastore
start_metastore

# Start HiveServer2
start_hiveserver2

# Keep container running
log_info "All Hive services are running"
tail -f "${HIVE_HOME}/logs/metastore.log" "${HIVE_HOME}/logs/hiveserver2.log" 