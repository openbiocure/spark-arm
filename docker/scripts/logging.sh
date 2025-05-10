#!/bin/bash

# Logging levels
declare -r LOG_LEVEL_DEBUG=0
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_WARN=2
declare -r LOG_LEVEL_ERROR=3

# Default log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log file configuration
LOG_FILE=${LOG_FILE:-"/opt/spark/logs/spark-container.log"}
LOG_MAX_SIZE=${LOG_MAX_SIZE:-10485760}  # 10MB
LOG_MAX_FILES=${LOG_MAX_FILES:-5}

# Logging function with levels and file output
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$(get_log_level_name $level)] $message"
    
    if [ $level -ge $LOG_LEVEL ]; then
        case $level in
            $LOG_LEVEL_DEBUG)
                echo "$log_entry"
                ;;
            $LOG_LEVEL_INFO)
                echo "$log_entry"
                ;;
            $LOG_LEVEL_WARN)
                echo "$log_entry" >&2
                ;;
            $LOG_LEVEL_ERROR)
                echo "$log_entry" >&2
                ;;
        esac
        
        # Append to log file if configured
        if [ -n "${LOG_FILE:-}" ]; then
            echo "$log_entry" >> "$LOG_FILE"
            rotate_logs_if_needed
        fi
    fi
}

# Get log level name
get_log_level_name() {
    case $1 in
        $LOG_LEVEL_DEBUG) echo "DEBUG" ;;
        $LOG_LEVEL_INFO) echo "INFO" ;;
        $LOG_LEVEL_WARN) echo "WARN" ;;
        $LOG_LEVEL_ERROR) echo "ERROR" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# Rotate logs if needed
rotate_logs_if_needed() {
    if [ -f "$LOG_FILE" ] && [ $(stat -f %z "$LOG_FILE") -gt $LOG_MAX_SIZE ]; then
        for ((i=$LOG_MAX_FILES-1; i>=1; i--)); do
            if [ -f "${LOG_FILE}.$i" ]; then
                mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
            fi
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
        touch "$LOG_FILE"
    fi
}

# Convenience functions for different log levels
log_debug() {
    log $LOG_LEVEL_DEBUG "$1"
}

log_info() {
    log $LOG_LEVEL_INFO "$1"
}

log_warn() {
    log $LOG_LEVEL_WARN "$1"
}

log_error() {
    log $LOG_LEVEL_ERROR "$1"
}

# Error handling function with stack trace
handle_error() {
    local script=$1
    local line=$2
    local exit_code=${3:-1}
    
    log_error "An error occurred in $script at line $line (exit code: $exit_code)"
    
    # Print stack trace if available
    if [ ${BASH_VERSION:-} ]; then
        local frame=0
        while caller $frame > /dev/null; do
            local trace=($(caller $frame))
            log_error "  at ${trace[1]}:${trace[0]} in function ${trace[2]}"
            ((frame++))
        done
    fi
    
    exit $exit_code
}

# Verify environment variable with custom error message
verify_env() {
    local var_name=$1
    local error_msg=${2:-"Required environment variable $var_name is not set"}
    local var_value=${!var_name:-}
    
    if [ -z "$var_value" ]; then
        log_error "$error_msg"
        exit 1
    fi
}

# Verify directory exists with custom error message
verify_dir() {
    local dir_path=$1
    local dir_name=$2
    local error_msg=${3:-"$dir_name directory does not exist: $dir_path"}
    
    if [ ! -d "$dir_path" ]; then
        log_error "$error_msg"
        exit 1
    fi
}

# Wait for file with timeout and custom error message
wait_for_file() {
    local pattern=$1
    local max_retries=${2:-30}
    local error_msg=${3:-"Failed to find file matching pattern '$pattern' after $max_retries attempts"}
    local retry_count=0
    local file=""
    
    while [ -z "$file" ] && [ $retry_count -lt $max_retries ]; do
        sleep 1
        file=$(find /opt/spark/logs -name "$pattern" -type f | head -n 1)
        retry_count=$((retry_count + 1))
        log_info "Attempt $retry_count/$max_retries to find file matching pattern: $pattern"
    done
    
    if [ -z "$file" ]; then
        log_error "$error_msg"
        exit 1
    fi
    
    echo "$file"
}

# Check if a process is running
check_process() {
    local process_name=$1
    local pid=$2
    
    if ! ps -p $pid > /dev/null; then
        log_error "Process $process_name (PID: $pid) is not running"
        return 1
    fi
    return 0
}

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    
    # Create or truncate log file
    touch "$LOG_FILE"
    
    log_info "Logging initialized. Log file: $LOG_FILE"
    log_info "Log level: $(get_log_level_name $LOG_LEVEL)"
} 