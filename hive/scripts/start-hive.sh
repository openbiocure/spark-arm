#!/bin/bash

set -e

echo "Debug: Current directory: $(pwd)"
echo "Debug: Current user: $(whoami)"
echo "Debug: Environment before logging init:"
env | grep -E "HOME|USER|LOG|HIVE_METASTORE"
echo "Debug: Logging script location: $(ls -l $(dirname "$0")/logging.sh)"

# Source logging functions and initialize logging
source "$(dirname "$0")/logging.sh"
echo "Debug: After sourcing logging.sh"
env | grep -E "HOME|USER|LOG|HIVE_METASTORE"

init_logging
echo "Debug: After init_logging"
env | grep -E "HOME|USER|LOG|HIVE_METASTORE"
echo "Debug: Log file location: $LOG_FILE"
echo "Debug: Log file permissions: $(ls -l $LOG_FILE 2>/dev/null || echo 'Log file does not exist')"

# Process hive-site.xml template with environment variables
log_info "Processing hive-site.xml template..."
if [ -f "${HIVE_HOME}/conf/hive-site.xml.template" ]; then
    # Export variables without defaults
    echo "Debug: Original HIVE_WAREHOUSE_DIR value: ${HIVE_WAREHOUSE_DIR}"
    export HIVE_WAREHOUSE_DIR="${HIVE_WAREHOUSE_DIR}"
    echo "Debug: After setting, HIVE_WAREHOUSE_DIR value: ${HIVE_WAREHOUSE_DIR}"
    
    # Export other variables without defaults
    export HIVE_METASTORE_DB_HOST="${HIVE_METASTORE_DB_HOST}"
    export HIVE_METASTORE_DB_PORT="${HIVE_METASTORE_DB_PORT}"
    export HIVE_METASTORE_DB_NAME="${HIVE_METASTORE_DB_NAME}"
    export HIVE_METASTORE_DB_USER="${HIVE_METASTORE_DB_USER}"
    export HIVE_METASTORE_DB_PASSWORD="${HIVE_METASTORE_DB_PASSWORD}"
    export HIVE_SERVER2_PORT="${HIVE_SERVER2_PORT}"
    export HIVE_SERVER2_BIND_HOST="${HIVE_SERVER2_BIND_HOST}"
    export HIVE_METASTORE_HOST="${HIVE_METASTORE_HOST}"
    export HIVE_METASTORE_PORT="${HIVE_METASTORE_PORT}"
    export HIVE_SCRATCH_DIR="${HIVE_SCRATCH_DIR}"
    
    echo "Debug: All environment variables before substitution:"
    env | grep -E "HIVE_|AWS_"
    
    # Now do the substitution
    envsubst < "${HIVE_HOME}/conf/hive-site.xml.template" > "${HIVE_HOME}/conf/hive-site.xml"
    log_info "Generated hive-site.xml from template"
    log_info "Contents of generated hive-site.xml:"
    cat "${HIVE_HOME}/conf/hive-site.xml"
else
    log_error "hive-site.xml.template not found at ${HIVE_HOME}/conf/hive-site.xml.template"
    exit 1
fi

# Function to check if a port is in use
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 1  # Return 1 if port is in use
    else
        return 0  # Return 0 if port is free
    fi
}

# Function to wait for a service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local max_attempts=30
    local attempt=1
    local log_file="${HIVE_HOME}/logs/${service,,}.log"

    log_info "Waiting for $service to be ready on $host:$port..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" >/dev/null 2>&1; then
            log_info "$service is ready!"
            return 0
        fi
        log_info "Attempt $attempt/$max_attempts: $service not ready yet, waiting..."
        if [ -f "$log_file" ]; then
            log_info "Recent $service logs:"
            tail -n 10 "$log_file"
        fi
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "$service failed to start after $max_attempts attempts"
    if [ -f "$log_file" ]; then
        log_error "Last 50 lines of $service logs:"
        tail -n 50 "$log_file"
    fi
    return 1
}

# Start Hive Metastore
start_metastore() {
    log_info "Starting Hive Metastore..."
    
    # Ensure logs directory exists and is writable
    mkdir -p ${HIVE_HOME}/logs
    chmod 777 ${HIVE_HOME}/logs
    
    # Verify driver exists and is readable
    if [ ! -f "${HIVE_HOME}/lib/postgresql.jar" ]; then
        log_error "PostgreSQL driver not found at ${HIVE_HOME}/lib/postgresql.jar"
        return 1
    fi
    
    # Start metastore with system properties
    log_info "Starting metastore with system properties..."
    java -cp "${HIVE_HOME}/lib/*:${HADOOP_HOME}/share/hadoop/common/*:${HADOOP_HOME}/share/hadoop/common/lib/*" \
         -Djavax.jdo.option.ConnectionDriverName=org.postgresql.Driver \
         -Djavax.jdo.option.ConnectionURL="jdbc:postgresql://${HIVE_METASTORE_DB_HOST:-postgresql}:${HIVE_METASTORE_DB_PORT:-5432}/${HIVE_METASTORE_DB_NAME:-hive}" \
         -Djavax.jdo.option.ConnectionUserName="${HIVE_METASTORE_DB_USER:-hive}" \
         -Djavax.jdo.option.ConnectionPassword="${HIVE_METASTORE_DB_PASSWORD:-hive}" \
         org.apache.hadoop.hive.metastore.HiveMetaStore > ${HIVE_HOME}/logs/metastore.log 2>&1 &
    METASTORE_PID=$!
    
    # Wait a moment to see if it starts
    sleep 2
    if ! ps -p $METASTORE_PID > /dev/null; then
        log_error "Metastore process died immediately. Logs:"
        cat "${HIVE_HOME}/logs/metastore.log"
        return 1
    fi
    
    # Show initial logs
    log_info "Initial metastore logs:"
    tail -n 50 "${HIVE_HOME}/logs/metastore.log"
    
    # Monitor process and logs while waiting
    local attempt=1
    local max_attempts=30
    while [ $attempt -le $max_attempts ]; do
        if ! ps -p $METASTORE_PID > /dev/null; then
            log_error "Metastore process died during startup. Logs:"
            tail -n 50 "${HIVE_HOME}/logs/metastore.log"
            return 1
        fi
        
        if nc -z localhost 9083 >/dev/null 2>&1; then
            log_info "Metastore is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: Metastore not ready yet, waiting..."
        log_info "Recent metastore logs:"
        tail -n 20 "${HIVE_HOME}/logs/metastore.log"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Metastore failed to start after $max_attempts attempts"
    log_error "Last 50 lines of metastore logs:"
    tail -n 50 "${HIVE_HOME}/logs/metastore.log"
    return 1
}

# Start HiveServer2
start_hiveserver2() {
    log_info "Starting HiveServer2..."
    log_info "Checking port 10000 status..."
    
    # Check if port is already in use
    if check_port 10000; then
        log_info "Port 10000 is free, proceeding..."
    else
        log_error "Port 10000 is already in use. Please free up the port and try again."
        return 1
    fi

    # Test PostgreSQL connectivity
    log_info "Testing PostgreSQL connectivity..."
    if ! pg_isready -h "${HIVE_METASTORE_DB_HOST}" -p "${HIVE_METASTORE_DB_PORT}" -U "${HIVE_METASTORE_DB_USER}" -d "${HIVE_METASTORE_DB_NAME}" >/dev/null 2>&1; then
        log_error "Cannot connect to PostgreSQL at ${HIVE_METASTORE_DB_HOST}:${HIVE_METASTORE_DB_PORT}"
        return 1
    fi
    log_info "PostgreSQL connection successful"

    # Create logs directory if it doesn't exist
    mkdir -p "${HIVE_HOME}/logs"
    chmod 777 "${HIVE_HOME}/logs"

    # Set JVM options for logging
    export HADOOP_OPTS="${HADOOP_OPTS} -Dhive.log.dir=${HIVE_HOME}/logs -Dhive.log.level=DEBUG -Dhive.root.logger=DRFA"
    export HADOOP_CLIENT_OPTS="${HADOOP_CLIENT_OPTS} -Dhive.log.dir=${HIVE_HOME}/logs -Dhive.log.level=DEBUG -Dhive.log.file=${HIVE_HOME}/logs/hiveserver2.log"

    log_info "Starting HiveServer2 with debug logging..."
    cd "${HIVE_HOME}" && \
        "${HIVE_HOME}/bin/hive" --service hiveserver2 \
        --hiveconf hive.server2.thrift.port=10000 \
        --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
        --hiveconf hive.server2.logging.operation.enabled=true \
        --hiveconf hive.server2.logging.operation.level=DEBUG \
        --hiveconf hive.server2.logging.operation.verbose=true \
        --hiveconf hive.server2.thrift.sasl.qop=auth \
        --hiveconf hive.server2.authentication=NONE \
        --hiveconf hive.server2.enable.doAs=false \
        --hiveconf hive.log.level=DEBUG 2>&1 | tee "${HIVE_HOME}/logs/hiveserver2.log"

    # If we get here, the foreground process exited
    local exit_code=${PIPESTATUS[0]}
    if [ $exit_code -ne 0 ]; then
        log_error "HiveServer2 failed to start with exit code $exit_code"
        log_error "Last 50 lines of output:"
        tail -n 50 "${HIVE_HOME}/logs/hiveserver2.log"
        return 1
    fi

    return 0
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