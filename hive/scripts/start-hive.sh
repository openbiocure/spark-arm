#!/bin/bash

set -e

# --- Debug Info ---
echo "Debug: Current directory: $(pwd)"
echo "Debug: Current user: $(whoami)"
echo "Debug: Environment before logging init:"
env | grep -E "HOME|USER|LOG|HIVE_METASTORE"

SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="${HIVE_HOME}/logs/hive-init.log"

echo "Debug: Logging script location: $(ls -l "${SCRIPT_DIR}/logging.sh")"
source "${SCRIPT_DIR}/logging.sh"

echo "Debug: After sourcing logging.sh"
env | grep -E "HOME|USER|LOG|HIVE_METASTORE"

init_logging
echo "Debug: After init_logging"
echo "Debug: Log file location: $LOG_FILE"
echo "Debug: Log file permissions: $(ls -l "$LOG_FILE" 2>/dev/null || echo 'Log file does not exist')"

# --- Configuration Functions ---
render_hive_config() {
    log_info "Rendering Hive configuration..."
    
    # Check template exists
    TEMPLATE="${HIVE_HOME}/conf/hive-site.xml.template"
    OUTPUT="${HIVE_HOME}/conf/hive-site.xml"
    
    if [[ ! -f "$TEMPLATE" ]]; then
        log_error "Template not found: $TEMPLATE"
        return 1
    fi

    # Export required variables
    export_vars=(
        HIVE_WAREHOUSE_DIR HIVE_METASTORE_DB_HOST HIVE_METASTORE_DB_PORT
        HIVE_METASTORE_DB_NAME HIVE_METASTORE_DB_USER HIVE_METASTORE_DB_PASSWORD
        HIVE_SERVER2_PORT HIVE_SERVER2_BIND_HOST HIVE_METASTORE_HOST
        HIVE_METASTORE_PORT HIVE_SCRATCH_DIR
    )

    for var in "${export_vars[@]}"; do
        export "$var"="${!var}"
    done

    # Log current environment
    log_info "Current Hive environment:"
    env | grep -E "HIVE_|AWS_"

    # Render configuration
    envsubst < "$TEMPLATE" > "$OUTPUT"
    log_info "Generated hive-site.xml from template"

    # Verify configuration
    log_info "Verifying rendered configuration..."
    
    # Check PostgreSQL connection settings
    log_info "Checking PostgreSQL connection settings..."
    local pg_url=$(grep -A1 "javax.jdo.option.ConnectionURL" "$OUTPUT" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    local pg_user=$(grep -A1 "javax.jdo.option.ConnectionUserName" "$OUTPUT" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    local pg_pass=$(grep -A1 "javax.jdo.option.ConnectionPassword" "$OUTPUT" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    
    log_info "PostgreSQL URL from config: $pg_url"
    log_info "PostgreSQL User from config: $pg_user"
    log_info "PostgreSQL Password from config: [HIDDEN]"
    
    # Verify against environment variables
    local expected_url="jdbc:postgresql://${HIVE_METASTORE_DB_HOST}:${HIVE_METASTORE_DB_PORT}/${HIVE_METASTORE_DB_NAME}"
    if [[ "$pg_url" != "$expected_url" ]]; then
        log_error "PostgreSQL URL mismatch!"
        log_error "Expected: $expected_url"
        log_error "Got: $pg_url"
        return 1
    fi
    
    if [[ "$pg_user" != "$HIVE_METASTORE_DB_USER" ]]; then
        log_error "PostgreSQL username mismatch!"
        log_error "Expected: $HIVE_METASTORE_DB_USER"
        log_error "Got: $pg_user"
        return 1
    fi
    
    if [[ "$pg_pass" != "$HIVE_METASTORE_DB_PASSWORD" ]]; then
        log_error "PostgreSQL password mismatch!"
        return 1
    fi
    
    # Check HiveServer2 settings
    log_info "Checking HiveServer2 settings..."
    local hs2_port=$(grep -A1 "hive.server2.thrift.port" "$OUTPUT" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    local hs2_host=$(grep -A1 "hive.server2.thrift.bind.host" "$OUTPUT" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    
    log_info "HiveServer2 Port from config: $hs2_port"
    log_info "HiveServer2 Host from config: $hs2_host"
    
    if [[ "$hs2_port" != "$HIVE_SERVER2_PORT" ]]; then
        log_error "HiveServer2 port mismatch!"
        log_error "Expected: $HIVE_SERVER2_PORT"
        log_error "Got: $hs2_port"
        return 1
    fi
    
    if [[ "$hs2_host" != "$HIVE_SERVER2_BIND_HOST" ]]; then
        log_error "HiveServer2 host mismatch!"
        log_error "Expected: $HIVE_SERVER2_BIND_HOST"
        log_error "Got: $hs2_host"
        return 1
    fi
    
    # Check warehouse and scratch directories
    log_info "Checking warehouse and scratch directories..."
    local warehouse_dir=$(grep -A1 "hive.metastore.warehouse.dir" "$OUTPUT" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    local scratch_dir=$(grep -A1 "hive.exec.scratchdir" "$OUTPUT" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    
    log_info "Warehouse directory from config: $warehouse_dir"
    log_info "Scratch directory from config: $scratch_dir"
    
    if [[ "$warehouse_dir" != "$HIVE_WAREHOUSE_DIR" ]]; then
        log_error "Warehouse directory mismatch!"
        log_error "Expected: $HIVE_WAREHOUSE_DIR"
        log_error "Got: $warehouse_dir"
        return 1
    fi
    
    if [[ "$scratch_dir" != "$HIVE_SCRATCH_DIR" ]]; then
        log_error "Scratch directory mismatch!"
        log_error "Expected: $HIVE_SCRATCH_DIR"
        log_error "Got: $scratch_dir"
        return 1
    fi
    
    log_info "All configuration checks passed successfully"
    log_info "Full configuration file:"
    cat "$OUTPUT"
    
    return 0
}

# --- Port Check ---
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        echo "Port $port is already in use. Please free up the port or use a different one."
        return 1
    fi
    return 0
}

# --- Wait Until Service Available ---
wait_for_service() {
    local host="$1" port="$2" name="$3"
    local log_file="${HIVE_HOME}/logs/${name,,}.log"

    for attempt in {1..30}; do
        nc -z "$host" "$port" && log_info "$name is ready!" && return 0
        log_info "Attempt $attempt/30: $name not ready yet, waiting..."
        [[ -f "$log_file" ]] && tail -n 10 "$log_file"
        sleep 2
    done

    log_error "$name failed to start after 30 attempts"
    [[ -f "$log_file" ]] && tail -n 50 "$log_file"
    return 1
}

# --- Setup Logging Configuration ---
setup_logging_config() {
    log_info "Setting up logging configuration..."
    
    # Copy and configure log4j2 properties
    local log4j_template="${HIVE_HOME}/conf/hive-log4j2.properties.template"
    local log4j_props="${HIVE_HOME}/conf/hive-log4j2.properties"
    
    if [[ ! -f "$log4j_template" ]]; then
        log_error "Log4j2 template not found: $log4j_template"
        return 1
    fi
    
    # Copy template to actual properties file
    cp "$log4j_template" "$log4j_props"
    chmod 644 "$log4j_props"
    
    # Ensure log directory exists and is writable
    mkdir -p "${HIVE_HOME}/logs"
    chmod 777 "${HIVE_HOME}/logs"
    
    # Set up environment variables for logging
    export HADOOP_OPTS+=" -Dhive.log.dir=${HIVE_HOME}/logs"
    export HADOOP_OPTS+=" -Dhive.log.level=DEBUG"
    export HADOOP_OPTS+=" -Dhive.root.logger=DRFA"
    export HADOOP_OPTS+=" -Dlog4j2.configurationFile=file://${log4j_props}"
    export HADOOP_CLIENT_OPTS+=" -Dhive.log.file=${HIVE_HOME}/logs/hiveserver2.log"
    export HADOOP_CLIENT_OPTS+=" -Dlog4j2.configurationFile=file://${log4j_props}"
    
    log_info "Logging configuration set up at: $log4j_props"
    return 0
}

# --- Test Port Binding ---
test_port_binding() {
    local port=$1
    log_info "Testing if we can bind to port $port..."
    
    # Try to bind using netcat
    nc -l -p $port &
    local nc_pid=$!
    sleep 2
    
    # Check if netcat is still running (meaning it successfully bound)
    if ps -p $nc_pid > /dev/null; then
        log_info "Successfully bound to port $port using netcat"
        # Kill the test process
        kill $nc_pid
        return 0
    else
        log_error "Failed to bind to port $port using netcat"
        log_error "This suggests a system-level issue preventing port binding"
        return 1
    fi
}

# --- Check and Create Required Directories ---
check_and_create_directories() {
    echo "=== Checking Required Directories ==="
    echo "Current user: $(whoami)"
    echo "Current directory: $(pwd)"
    echo "Filesystem status:"
    df -h .
    
    # Define directories to check/create
    local dirs=(
        "/opt/hive/warehouse"
        "/opt/hive/scratch"
        "/opt/hive/logs"
    )
    
    # Check and create each directory
    for dir in "${dirs[@]}"; do
        echo -e "\nChecking directory: $dir"
        echo "Current status:"
        ls -ld "$dir" 2>/dev/null || echo "Directory does not exist"
        
        # Try to create directory if it doesn't exist
        if [[ ! -d "$dir" ]]; then
            echo "Creating directory: $dir"
            if ! mkdir -p "$dir"; then
                echo "✗ Failed to create directory: $dir"
                echo "Parent directory status:"
                ls -ld "$(dirname "$dir")"
                echo "Filesystem status:"
                df -h .
                return 1
            fi
        fi
        
        # Set ownership and permissions
        echo "Setting permissions for: $dir"
        if ! chown -R hive:hive "$dir"; then
            echo "✗ Failed to set ownership for: $dir"
            echo "Current ownership:"
            ls -ld "$dir"
            return 1
        fi
        
        if ! chmod 777 "$dir"; then
            echo "✗ Failed to set permissions for: $dir"
            echo "Current permissions:"
            ls -ld "$dir"
            return 1
        fi
        
        # Verify directory is writable by hive user
        echo "Verifying write access for: $dir"
        if ! touch "$dir/.testfile" 2>/dev/null; then
            echo "✗ Directory $dir is not writable by hive user"
            echo "Current permissions:"
            ls -ld "$dir"
            echo "Parent directory permissions:"
            ls -ld "$(dirname "$dir")"
            return 1
        fi
        rm -f "$dir/.testfile"
        echo "✓ Directory $dir exists and is writable by hive user"
    done
    
    echo -e "\n=== Directory Check Complete ==="
    echo "Final directory status:"
    for dir in "${dirs[@]}"; do
        ls -ld "$dir"
    done
    return 0
}

# --- Start Metastore ---
start_metastore() {
    echo "Starting Hive Metastore..."
    
    # Check and create required directories
    check_and_create_directories || {
        echo "Failed to set up required directories"
        return 1
    }
    
    # Check if port is available
    check_port 9083 || return 1
    
    # Check and fix logging
    check_and_fix_logging
    
    # Start metastore with proper classpath and logging
    cd /opt/hive && nohup java -cp "/opt/hive/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/common/lib/*:/opt/hadoop/share/hadoop/hdfs/*:/opt/hadoop/share/hadoop/hdfs/lib/*:/opt/hadoop/share/hadoop/mapreduce/*:/opt/hadoop/share/hadoop/mapreduce/lib/*:/opt/hadoop/share/hadoop/yarn/*:/opt/hadoop/share/hadoop/yarn/lib/*" \
        -Dlog4j2.configurationFile=file:///opt/hive/conf/hive-log4j2.properties \
        -Dhive.log.dir=/opt/hive/logs \
        -Dhive.log.file=metastore.log \
        -Dhive.log.level=DEBUG \
        -Djavax.jdo.option.ConnectionDriverName=org.postgresql.Driver \
        -Djavax.jdo.option.ConnectionURL="jdbc:postgresql://${HIVE_METASTORE_DB_HOST}:${HIVE_METASTORE_DB_PORT}/${HIVE_METASTORE_DB_NAME}" \
        -Djavax.jdo.option.ConnectionUserName="${HIVE_METASTORE_DB_USER}" \
        -Djavax.jdo.option.ConnectionPassword="${HIVE_METASTORE_DB_PASSWORD}" \
        org.apache.hadoop.hive.metastore.HiveMetaStore \
        --hiveconf hive.metastore.uris=thrift://0.0.0.0:9083 \
        > /opt/hive/logs/metastore.out 2>&1 &
    
    # Wait for metastore to start
    echo "Waiting for metastore to start..."
    sleep 10
    
    # Check if metastore is running
    if jps | grep -q "HiveMetaStore"; then
        echo "Hive Metastore started successfully"
        return 0
    else
        echo "Failed to start Hive Metastore. Check logs at /opt/hive/logs/metastore.log"
        return 1
    fi
}

# --- Diagnostic Functions ---
check_hiveserver2_status() {
    local pid=$1
    log_info "Running diagnostic checks for HiveServer2..."
    
    # Check if process is running
    log_info "Checking HiveServer2 process..."
    if ps -p $pid > /dev/null; then
        log_info "HiveServer2 process is running with PID: $pid"
        ps aux | grep HiveServer2 | grep -v grep
    else
        log_error "HiveServer2 process is not running!"
        log_error "Last 50 lines of HiveServer2 log:"
        tail -n 50 "${HIVE_HOME}/logs/hiveserver2.log"
    fi

    # Check port binding
    log_info "Checking port 10000 binding..."
    netstat -tulnp 2>/dev/null | grep 10000 || {
        log_error "Port 10000 is not bound!"
        log_info "Current network connections:"
        netstat -tulnp 2>/dev/null
    }

    # Verify configuration
    log_info "Verifying HiveServer2 configuration..."
    log_info "HiveServer2 bind host and port settings:"
    grep -E 'bind.host|thrift.port' "${HIVE_HOME}/conf/hive-site.xml"

    # Check logs for errors
    log_info "Checking for errors in HiveServer2 logs..."
    if grep -i "error\|exception\|failed" "${HIVE_HOME}/logs/hiveserver2.log" | tail -n 10; then
        log_error "Found errors in HiveServer2 logs"
    else
        log_info "No immediate errors found in logs"
    fi

    # If HiveServer2 is not running properly, provide troubleshooting command
    if ! ps -p $pid > /dev/null || ! netstat -tulnp 2>/dev/null | grep -q 10000; then
        log_error "HiveServer2 is not running properly. To troubleshoot, run:"
        log_error "docker exec -it \$(docker ps | grep hive-arm | awk '{print \$1}') bash"
        log_error "Then inside the container:"
        log_error "1. Check logs: tail -f ${HIVE_HOME}/logs/hiveserver2.log"
        log_error "2. Check process: ps aux | grep HiveServer2"
        log_error "3. Check port: netstat -tulnp | grep 10000"
        log_error "4. Check config: cat ${HIVE_HOME}/conf/hive-site.xml"
        return 1
    fi

    log_info "HiveServer2 appears to be running properly"
    return 0
}

# --- Start HiveServer2 ---
start_hiveserver2() {
    echo "Starting HiveServer2..."
    
    # Check and create required directories
    check_and_create_directories || {
        echo "Failed to set up required directories"
        return 1
    }
    
    # Check if port is available
    check_port 10000 || return 1
    
    # Check and fix logging
    check_and_fix_logging
    
    # Start HiveServer2 with proper classpath and logging
    cd /opt/hive && nohup java \
        --add-opens java.base/java.net=ALL-UNNAMED \
        --add-opens java.base/java.lang=ALL-UNNAMED \
        --add-opens java.base/java.nio=ALL-UNNAMED \
        -cp "/opt/hive/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/common/lib/*:/opt/hadoop/share/hadoop/hdfs/*:/opt/hadoop/share/hadoop/hdfs/lib/*:/opt/hadoop/share/hadoop/mapreduce/*:/opt/hadoop/share/hadoop/mapreduce/lib/*:/opt/hadoop/share/hadoop/yarn/*:/opt/hadoop/share/hadoop/yarn/lib/*" \
        -Dlog4j2.configurationFile=file:///opt/hive/conf/hive-log4j2.properties \
        -Dhive.log.dir=/opt/hive/logs \
        -Dhive.log.file=hiveserver2.log \
        -Dhive.log.level=DEBUG \
        -Dhive.server2.thrift.sasl.qop=none \
        -Dhive.server2.authentication=NONE \
        -Dhive.server2.enable.doAs=false \
        -Dhive.server2.transport.mode=binary \
        -Dhive.server2.thrift.min.worker.threads=5 \
        -Dhive.server2.thrift.max.worker.threads=500 \
        -Dhive.server2.thrift.sasl.enabled=false \
        org.apache.hive.service.server.HiveServer2 \
        --hiveconf hive.server2.thrift.port=10000 \
        --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
        --hiveconf hive.server2.logging.operation.enabled=true \
        --hiveconf hive.server2.logging.operation.verbose=true \
        --hiveconf hive.metastore.uris=thrift://localhost:9083 \
        > /opt/hive/logs/hiveserver2.out 2>&1 &
    
    # Wait for HiveServer2 to start
    echo "Waiting for HiveServer2 to start..."
    sleep 10
    
    # Check if HiveServer2 is running
    if jps | grep -q "HiveServer2"; then
        echo "HiveServer2 started successfully"
        return 0
    else
        echo "Failed to start HiveServer2. Check logs at /opt/hive/logs/hiveserver2.log"
        return 1
    fi
}

# --- Create Basic Log4j2 Configuration ---
create_log4j2_config() {
    local config_file="/opt/hive/conf/hive-log4j2.properties"
    echo "Creating basic log4j2 configuration at $config_file..."
    
    cat > "$config_file" << 'EOF'
# Basic log4j2 configuration for Hive
status = INFO
name = HiveLog4j2Config

# Appenders
appenders = console, file

# Console appender
appender.console.type = Console
appender.console.name = console
appender.console.layout.type = PatternLayout
appender.console.layout.pattern = %d{yyyy-MM-dd HH:mm:ss.SSS} %-5p %c{1}:%L - %m%n

# File appender
appender.file.type = RollingFile
appender.file.name = file
appender.file.fileName = ${sys:hive.log.dir}/${sys:hive.log.file}
appender.file.filePattern = ${sys:hive.log.dir}/${sys:hive.log.file}.%d{yyyy-MM-dd}
appender.file.layout.type = PatternLayout
appender.file.layout.pattern = %d{yyyy-MM-dd HH:mm:ss.SSS} %-5p %c{1}:%L - %m%n
appender.file.policies.type = Policies
appender.file.policies.time.type = TimeBasedTriggeringPolicy
appender.file.policies.time.interval = 1
appender.file.policies.time.modulate = true
appender.file.strategy.type = DefaultRolloverStrategy
appender.file.strategy.max = 30

# Root logger
rootLogger.level = ${sys:hive.log.level}
rootLogger.appenderRefs = console, file
rootLogger.appenderRef.console.ref = console
rootLogger.appenderRef.file.ref = file

# Hive logger
logger.hive.name = org.apache.hadoop.hive
logger.hive.level = ${sys:hive.log.level}
logger.hive.additivity = false
logger.hive.appenderRefs = console, file
logger.hive.appenderRef.console.ref = console
logger.hive.appenderRef.file.ref = file
EOF

    chown hive:hive "$config_file"
    chmod 644 "$config_file"
    echo "Created log4j2 configuration with proper permissions"
}

# --- Check and Fix Logging Configuration ---
check_and_fix_logging() {
    echo "=== Checking Logging Configuration ==="
    
    # Check if log4j2 config exists
    echo "1. Checking log4j2 configuration..."
    if [[ ! -f "/opt/hive/conf/hive-log4j2.properties" ]]; then
        echo "hive-log4j2.properties not found in /opt/hive/conf/"
        echo "Creating basic log4j2 configuration..."
        create_log4j2_config
    fi
    ls -l "/opt/hive/conf/hive-log4j2.properties"
    
    # Check logs directory permissions
    echo -e "\n2. Checking logs directory permissions..."
    if [[ ! -d "/opt/hive/logs" ]]; then
        echo "Creating logs directory..."
        mkdir -p "/opt/hive/logs"
    fi
    ls -ld "/opt/hive/logs"
    if [[ ! -w "/opt/hive/logs" ]]; then
        echo "Fixing logs directory permissions..."
        chown -R hive:hive "/opt/hive/logs"
        chmod 777 "/opt/hive/logs"
        echo "New permissions:"
        ls -ld "/opt/hive/logs"
    fi
    
    # Create log files with proper permissions
    echo -e "\n3. Creating log files..."
    touch "/opt/hive/logs/metastore.log" "/opt/hive/logs/hiveserver2.log"
    chown hive:hive "/opt/hive/logs/metastore.log" "/opt/hive/logs/hiveserver2.log"
    chmod 666 "/opt/hive/logs/metastore.log" "/opt/hive/logs/hiveserver2.log"
    
    # Verify log files exist and are writable
    echo -e "\n4. Verifying log files..."
    for log_file in "/opt/hive/logs/metastore.log" "/opt/hive/logs/hiveserver2.log"; do
        if [[ -f "$log_file" && -w "$log_file" ]]; then
            echo "✓ $log_file exists and is writable"
        else
            echo "✗ $log_file is missing or not writable"
            return 1
        fi
    done
    
    echo -e "\n=== Logging Configuration Check Complete ==="
}

# --- Main ---
echo "=== Starting Hive Services ==="
echo "Environment:"
env | grep -E "HIVE_|HOME|USER|LOG"
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Filesystem status:"
df -h .

# Initialize logging
init_logging

# Render configuration
render_hive_config || {
    log_error "Failed to render Hive configuration"
    exit 1
}

# Setup logging configuration
setup_logging_config || {
    log_error "Failed to set up logging configuration"
    exit 1
}

# Start services
log_info "Starting Hive services..."

# Start Metastore
start_metastore || {
    log_error "Failed to start Hive Metastore"
    exit 1
}

# Start HiveServer2
start_hiveserver2 || {
    log_error "Failed to start HiveServer2"
    exit 1
}

# Tail logs to keep container alive
log_info "All Hive services are running"
tail -f "${HIVE_HOME}/logs/metastore.log" "${HIVE_HOME}/logs/hiveserver2.log"