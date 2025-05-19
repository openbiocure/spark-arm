#!/bin/bash

# Logging functions for Hive scripts
# Usage: source /opt/hive/bin/logging.sh

# Initialize logging
init_logging() {
    # Determine if we're in installation mode or runtime mode
    if [ -f "/tmp/install-hadoop.sh" ]; then
        # Installation mode - use /tmp
        export LOG_FILE="/tmp/hive-install.log"
    else
        # Runtime mode - use Hive logs directory
        export LOG_FILE="${HIVE_HOME}/logs/hive.log"
        # Ensure logs directory exists and is writable
        mkdir -p "${HIVE_HOME}/logs"
        touch "$LOG_FILE"
        chmod 666 "$LOG_FILE"
    fi
}

# Log levels
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE"
}

# Error handler
handle_error() {
    local script=$1
    local line=$2
    local exit_code=$3
    
    log_error "Error in $script at line $line (exit code: $exit_code)"
    exit "$exit_code"
} 