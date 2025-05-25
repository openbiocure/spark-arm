#!/bin/bash

set -e

# Script version and generation timestamp
SCRIPT_VERSION="1.6.0"
SCRIPT_GENERATED_AT="2024-05-25T19:35:00Z"  # Last modified: May 25, 2024
echo "=== Hive Start Script ==="
echo "Version: $SCRIPT_VERSION"
echo "Generated: $SCRIPT_GENERATED_AT"
echo "========================"

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
        HIVE_METASTORE_PORT HIVE_SCRATCH_DIR HIVE_SERVER2_AUTHENTICATION
        HIVE_LOG_LEVEL
    )

    # Set notification-related properties with simpler names
    export NOTIFICATION_API_AUTH="false"
    export METASTORE_SETUGI="false"

    for var in "${export_vars[@]}"; do
        export "$var"="${!var}"
    done

    # Log current environment
    log_info "Current Hive environment:"
    env | grep -E "HIVE_|AWS_"

    # Render configuration
    log_info "Current template content:"
    cat "$TEMPLATE"
    log_info "Environment variables before substitution:"
    env | grep -E "HIVE_METASTORE_EVENT|HIVE_METASTORE_EXECUTE"
    envsubst < "$TEMPLATE" > "$OUTPUT"
    log_info "Generated hive-site.xml content:"
    cat "$OUTPUT"

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
    
    local conf_dir="${HIVE_HOME}/conf"
    local original_log4j="${conf_dir}/hive-log4j2.properties"
    local target_log4j="${conf_dir}/log4j2.xml"
    local legacy_log4j="${conf_dir}/log4j.properties"
    
    # Ensure log directory exists and is writable
    mkdir -p "${HIVE_HOME}/logs"
    chmod 777 "${HIVE_HOME}/logs"
    
    # If log4j2.xml doesn't exist but hive-log4j2.properties does, copy it
    if [[ -f "$original_log4j" && ! -f "$target_log4j" ]]; then
        log_info "Copying $original_log4j to $target_log4j for compatibility..."
        cp "$original_log4j" "$target_log4j"
    fi
    
    # Create a legacy log4j.properties file as fallback
    if [[ ! -f "$legacy_log4j" ]]; then
        log_info "Creating legacy log4j.properties for compatibility..."
        cat <<EOF > "$legacy_log4j"
# Root logger option
log4j.rootLogger=\${hive.log.level:-DEBUG}, console, file

# Direct log messages to console
log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.Target=System.out
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=[%d{yyyy-MM-dd HH:mm:ss}] %-5p %c{1} [%t] - %m%n

# Direct log messages to a log file
log4j.appender.file=org.apache.log4j.RollingFileAppender
log4j.appender.file.File=\${hive.log.dir}/\${hive.log.file}
log4j.appender.file.MaxFileSize=100MB
log4j.appender.file.MaxBackupIndex=10
log4j.appender.file.layout=org.apache.log4j.PatternLayout
log4j.appender.file.layout.ConversionPattern=[%d{yyyy-MM-dd HH:mm:ss}] %-5p %c{1} [%t] - %m%n

# Set specific logger levels
log4j.logger.DataNucleus=ERROR
log4j.logger.org.apache.hadoop.hive.ql.log.PerfLogger=INFO
log4j.logger.com.amazonaws=WARN
log4j.logger.org.apache.http=WARN
EOF
    fi
    
    # If neither exists, create a default XML configuration
    if [[ ! -f "$target_log4j" ]]; then
        log_warn "log4j2.xml not found. Creating a default configuration..."
        # Create file with clean XML declaration first
        printf '<?xml version="1.0" encoding="UTF-8"?>\n' > "$target_log4j"
        # Then append the rest of the configuration
        cat <<EOF >> "$target_log4j"
<Configuration status="WARN" name="HiveLogConfig" monitorInterval="30">
    <Properties>
        <Property name="LOG_PATTERN">[%d{yyyy-MM-dd HH:mm:ss}] %-5p %c{1} [%t] - %m%n</Property>
        <Property name="LOG_FILE_PATH">\${sys:hive.log.dir}/\${sys:hive.log.file}</Property>
    </Properties>

    <Appenders>
        <Console name="console" target="SYSTEM_OUT">
            <PatternLayout pattern="\${LOG_PATTERN}"/>
        </Console>
        
        <RollingRandomAccessFile name="file" 
                                fileName="\${LOG_FILE_PATH}"
                                filePattern="\${LOG_FILE_PATH}.%i">
            <PatternLayout pattern="\${LOG_PATTERN}"/>
            <Policies>
                <SizeBasedTriggeringPolicy size="100MB"/>
            </Policies>
            <DefaultRolloverStrategy max="10"/>
        </RollingRandomAccessFile>
    </Appenders>

    <Loggers>
        <Logger name="DataNucleus" level="ERROR"/>
        <Logger name="org.apache.hadoop.hive.ql.log.PerfLogger" level="INFO"/>
        <Logger name="com.amazonaws" level="WARN"/>
        <Logger name="org.apache.http" level="WARN"/>
        
        <Root level="\${sys:hive.log.level:-DEBUG}">
            <AppenderRef ref="console"/>
            <AppenderRef ref="file"/>
        </Root>
    </Loggers>
</Configuration>
EOF
        log_info "Created default log4j2.xml with both console and file appenders"
    else
        # If file exists but might have BOM, recreate it cleanly
        if ! head -n1 "$target_log4j" | grep -q '^<?xml'; then
            log_info "Recreating log4j2.xml to ensure clean XML format..."
            # Backup the existing file
            mv "$target_log4j" "${target_log4j}.bak"
            # Create new file with clean XML declaration
            printf '<?xml version="1.0" encoding="UTF-8"?>\n' > "$target_log4j"
            # Append the rest of the content, skipping any existing XML declaration
            grep -v '^<?xml' "${target_log4j}.bak" >> "$target_log4j"
            rm "${target_log4j}.bak"
        fi
    fi
    
    # Set up environment variables for logging - using a single source of truth
    export HIVE_LOG_LEVEL="${HIVE_LOG_LEVEL:-DEBUG}"
    
    # Clear any existing HADOOP_OPTS logging settings
    export HADOOP_OPTS=$(echo "$HADOOP_OPTS" | sed -E 's/-D(hive\.log\.|log4j2?\.).*?( |$)//g')
    
    # Set logging system properties in a consistent way - try both log4j2 and legacy properties
    export HADOOP_OPTS+=" -Dlog4j2.configurationFile=${target_log4j}"
    export HADOOP_OPTS+=" -Dlog4j.configuration=${legacy_log4j}"
    export HADOOP_OPTS+=" -Dlog4j.debug=true"
    export HADOOP_OPTS+=" -Dlog4j2.debug=true"
    export HADOOP_OPTS+=" -Dlog4j2.statusLogger.level=TRACE"
    export HADOOP_OPTS+=" -Dorg.apache.logging.log4j.simplelog.StatusLogger.level=TRACE"
    export HADOOP_OPTS+=" -Dhive.log.dir=${HIVE_HOME}/logs"
    export HADOOP_OPTS+=" -Dhive.log.level=${HIVE_LOG_LEVEL}"
    export HADOOP_OPTS+=" -Dhive.perflogger.log.level=${HIVE_LOG_LEVEL}"
    
    # Add conf directory to classpath
    export HADOOP_OPTS+=" -Djava.class.path=${conf_dir}:\${java.class.path}"
    
    # Set client options separately
    export HADOOP_CLIENT_OPTS+=" -Dlog4j2.configurationFile=${target_log4j}"
    export HADOOP_CLIENT_OPTS+=" -Dlog4j.configuration=${legacy_log4j}"
    export HADOOP_CLIENT_OPTS+=" -Dlog4j.debug=true"
    export HADOOP_CLIENT_OPTS+=" -Dlog4j2.debug=true"
    export HADOOP_CLIENT_OPTS+=" -Dlog4j2.statusLogger.level=TRACE"
    export HADOOP_CLIENT_OPTS+=" -Dorg.apache.logging.log4j.simplelog.StatusLogger.level=TRACE"
    export HADOOP_CLIENT_OPTS+=" -Dhive.log.dir=${HIVE_HOME}/logs"
    export HADOOP_CLIENT_OPTS+=" -Dhive.log.level=${HIVE_LOG_LEVEL}"
    export HADOOP_CLIENT_OPTS+=" -Djava.class.path=${conf_dir}:\${java.class.path}"
    
    log_info "Logging configuration set up at: $target_log4j (and $legacy_log4j as fallback)"
    log_info "HIVE_LOG_LEVEL set to: ${HIVE_LOG_LEVEL}"
    log_info "HADOOP_OPTS logging settings:"
    echo "$HADOOP_OPTS" | tr ' ' '\n' | grep -E 'hive\.log\.|log4j'
    
    # Verify the log4j2 configuration files
    echo "===== Log4j2 Config Files ====="
    echo "XML Config:"
    ls -l "$target_log4j"
    cat "$target_log4j"
    echo -e "\nLegacy Config:"
    ls -l "$legacy_log4j"
    cat "$legacy_log4j"
    
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
        if ! chown -R hive:hive "$dir"; then
            echo "⚠ Skipping chown: not permitted under fsGroup with non-root user"
            ls -ld "$dir"
            # Optionally: return 0 here if you want to continue
            return 0
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
    
    # Setup logging configuration
    setup_logging_config || {
        echo "Failed to set up logging configuration"
        return 1
    }
    
    # Start metastore with proper classpath and logging
    cd "${HIVE_HOME}" && {
        echo "Starting metastore with logging configuration:"
        echo "HADOOP_OPTS: $HADOOP_OPTS"
        echo "Log file: ${HIVE_HOME}/logs/metastore.log"
        echo "Log level: ${HIVE_LOG_LEVEL:-DEBUG}"
        
        nohup java \
            -cp "${HIVE_HOME}/lib/*:\
${HADOOP_HOME}/share/hadoop/common/*:\
${HADOOP_HOME}/share/hadoop/common/lib/*:\
${HADOOP_HOME}/share/hadoop/hdfs/*:\
${HADOOP_HOME}/share/hadoop/hdfs/lib/*:\
${HADOOP_HOME}/share/hadoop/mapreduce/*:\
${HADOOP_HOME}/share/hadoop/mapreduce/lib/*:\
${HADOOP_HOME}/share/hadoop/yarn/*:\
${HADOOP_HOME}/share/hadoop/yarn/lib/*:\
${HIVE_HOME}/conf" \
            -Dlog4j2.debug=true \
            -Dlog4j.debug=true \
            -Dlog4j2.statusLogger.level=TRACE \
            -Dorg.apache.logging.log4j.simplelog.StatusLogger.level=TRACE \
            -Dlog4j2.configurationFile=${HIVE_HOME}/conf/log4j2.xml \
            -Dlog4j.configuration=${HIVE_HOME}/conf/log4j.properties \
            -Dhive.log.file=metastore.log \
            -Dhive.log.dir=${HIVE_HOME}/logs \
            -Dhive.log.level=${HIVE_LOG_LEVEL:-DEBUG} \
            org.apache.hadoop.hive.metastore.HiveMetaStore \
            --hiveconf hive.metastore.uris=thrift://0.0.0.0:9083 \
            > "${HIVE_HOME}/logs/metastore.out" 2>&1 &
    }
    
    # Wait for metastore to start
    echo "Waiting for metastore to start..."
    sleep 10
    
    # Check if metastore is running and verify its logging
    if jps | grep -q "HiveMetaStore"; then
        echo "Hive Metastore started successfully"
        echo "Checking metastore process and logging:"
        ps aux | grep HiveMetaStore | grep -v grep
        echo "Checking metastore log file:"
        ls -l "${HIVE_HOME}/logs/metastore.log"
        echo "Last 20 lines of metastore.out:"
        tail -n 20 "${HIVE_HOME}/logs/metastore.out"
        return 0
    else
        echo "Failed to start Hive Metastore. Check logs at ${HIVE_HOME}/logs/metastore.log"
        echo "Contents of metastore.out:"
        cat "${HIVE_HOME}/logs/metastore.out"
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
    
    # Setup logging configuration
    setup_logging_config || {
        echo "Failed to set up logging configuration"
        return 1
    }
    
    # Start HiveServer2 with proper classpath and logging
    cd "${HIVE_HOME}" && {
        echo "Starting HiveServer2 with logging configuration:"
        echo "HADOOP_OPTS: $HADOOP_OPTS"
        echo "Log file: ${HIVE_HOME}/logs/hiveserver2.log"
        echo "Log level: ${HIVE_LOG_LEVEL:-DEBUG}"
        
        nohup java \
            --add-opens java.base/java.net=ALL-UNNAMED \
            --add-opens java.base/java.lang=ALL-UNNAMED \
            --add-opens java.base/java.nio=ALL-UNNAMED \
            -cp "${HIVE_HOME}/lib/*:\
${HADOOP_HOME}/share/hadoop/common/*:\
${HADOOP_HOME}/share/hadoop/common/lib/*:\
${HADOOP_HOME}/share/hadoop/hdfs/*:\
${HADOOP_HOME}/share/hadoop/hdfs/lib/*:\
${HADOOP_HOME}/share/hadoop/mapreduce/*:\
${HADOOP_HOME}/share/hadoop/mapreduce/lib/*:\
${HADOOP_HOME}/share/hadoop/yarn/*:\
${HADOOP_HOME}/share/hadoop/yarn/lib/*:\
${HIVE_HOME}/conf" \
            -Dlog4j2.debug=true \
            -Dlog4j.debug=true \
            -Dlog4j2.statusLogger.level=TRACE \
            -Dorg.apache.logging.log4j.simplelog.StatusLogger.level=TRACE \
            -Dlog4j2.configurationFile=${HIVE_HOME}/conf/log4j2.xml \
            -Dlog4j.configuration=${HIVE_HOME}/conf/log4j.properties \
            -Dhive.log.file=hiveserver2.log \
            -Dhive.log.dir=${HIVE_HOME}/logs \
            -Dhive.log.level=${HIVE_LOG_LEVEL:-DEBUG} \
            org.apache.hive.service.server.HiveServer2 \
            --hiveconf hive.server2.thrift.port=10000 \
            --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
            --hiveconf hive.server2.logging.operation.enabled=true \
            --hiveconf hive.server2.logging.operation.verbose=true \
            --hiveconf hive.metastore.uris=thrift://localhost:9083 \
            > "${HIVE_HOME}/logs/hiveserver2.out" 2>&1 &
    }
    
    # Wait for HiveServer2 to start
    echo "Waiting for HiveServer2 to start..."
    sleep 10
    
    # Check if HiveServer2 is running
    if jps | grep -q "HiveServer2"; then
        echo "HiveServer2 started successfully"
        return 0
    else
        echo "Failed to start HiveServer2. Check logs at ${HIVE_HOME}/logs/hiveserver2.log"
        return 1
    fi
}

# --- Check and Fix Logging Configuration ---
check_and_fix_logging() {
    echo "=== Checking Logging Configuration ==="
    echo "Current directory: $(pwd)"
    echo "Current user: $(whoami)"
    echo "HIVE_HOME: ${HIVE_HOME}"
    
    # Check if log4j2 config exists
    echo "1. Checking log4j2 configuration..."
    local conf_dir="${HIVE_HOME}/conf"
    local log4j_config="${conf_dir}/log4j2.xml"
    local hive_log4j_config="${conf_dir}/hive-log4j2.properties"
    echo "Looking for log4j2 config at: $log4j_config"
    
    # If log4j2.xml doesn't exist but hive-log4j2.properties does, copy it
    if [[ -f "$hive_log4j_config" && ! -f "$log4j_config" ]]; then
        echo "Copying $hive_log4j_config to $log4j_config for compatibility..."
        cp "$hive_log4j_config" "$log4j_config"
    fi
    
    if [[ ! -f "$log4j_config" ]]; then
        echo "✗ log4j2.xml not found in ${conf_dir}/"
        echo "Contents of ${conf_dir}/:"
        ls -la "${conf_dir}/"
        return 1
    fi
    echo "✓ Log4j2 config found at: $log4j_config"
    echo "Log4j2 config status:"
    ls -l "$log4j_config"
    
    # Check logs directory permissions
    echo -e "\n2. Checking logs directory permissions..."
    local logs_dir="${HIVE_HOME}/logs"
    echo "Looking for logs directory at: $logs_dir"
    if [[ ! -d "$logs_dir" ]]; then
        echo "Creating logs directory..."
        mkdir -p "$logs_dir"
    fi
    echo "Logs directory status:"
    ls -ld "$logs_dir"
    if [[ ! -w "$logs_dir" ]]; then
        echo "Fixing logs directory permissions..."
        chown -R hive:hive "$logs_dir"
        chmod 777 "$logs_dir"
        echo "New permissions:"
        ls -ld "$logs_dir"
    fi
    
    # Create log files with proper permissions
    echo -e "\n3. Creating log files..."
    local metastore_log="${logs_dir}/metastore.log"
    local hiveserver2_log="${logs_dir}/hiveserver2.log"
    echo "Creating log files in: $logs_dir"
    touch "$metastore_log" "$hiveserver2_log"
    chown hive:hive "$metastore_log" "$hiveserver2_log"
    chmod 666 "$metastore_log" "$hiveserver2_log"
    
    # Verify log files exist and are writable
    echo -e "\n4. Verifying log files..."
    for log_file in "$metastore_log" "$hiveserver2_log"; do
        if [[ -f "$log_file" && -w "$log_file" ]]; then
            echo "✓ $log_file exists and is writable"
            echo "File details:"
            ls -l "$log_file"
        else
            echo "✗ $log_file is missing or not writable"
            echo "Directory contents:"
            ls -la "$(dirname "$log_file")"
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

# Check if HiveServer2 is enabled in configuration
if grep -q "<name>hive.server2.enabled</name>.*<value>true</value>" "${HIVE_HOME}/conf/hive-site.xml"; then
    log_info "HiveServer2 is enabled in configuration, starting..."
    start_hiveserver2 || {
        log_error "Failed to start HiveServer2"
        exit 1
    }
else
    log_info "HiveServer2 is disabled in configuration, skipping..."
fi

# Tail logs to keep container alive
log_info "All configured Hive services are running"
if grep -q "<name>hive.server2.enabled</name>.*<value>true</value>" "${HIVE_HOME}/conf/hive-site.xml"; then
    tail -f "${HIVE_HOME}/logs/metastore.log" "${HIVE_HOME}/logs/hiveserver2.log"
else
    tail -f "${HIVE_HOME}/logs/metastore.log"
fi