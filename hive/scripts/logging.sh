#!/bin/bash

# Define colors
declare -A COLORS=(
    [RESET]="\033[0m"
    [RED]="\033[31m"
    [GREEN]="\033[32m"
    [YELLOW]="\033[33m"
    [BLUE]="\033[34m"
    [MAGENTA]="\033[35m"
    [CYAN]="\033[36m"
    [WHITE]="\033[37m"
    [BOLD]="\033[1m"
)

# Define log levels with their colors
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

declare -A LOG_COLORS=(
    [DEBUG]="${COLORS[CYAN]}"
    [INFO]="${COLORS[GREEN]}"
    [WARN]="${COLORS[YELLOW]}"
    [ERROR]="${COLORS[RED]}${COLORS[BOLD]}"
)

# Initialize logging
init_logging() {
    # Set default log level if not set
    : "${LOG_LEVEL:=INFO}"
    
    # Get numeric value for current log level
    CURRENT_LEVEL=${LOG_LEVELS[$LOG_LEVEL]:-1}
}

# Log a message with timestamp and level
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=${LOG_COLORS[$level]:-${COLORS[RESET]}}
    
    # Get numeric value for message level
    local level_num=${LOG_LEVELS[$level]:-1}
    
    # Only log if message level is >= current level
    if [ $level_num -ge $CURRENT_LEVEL ]; then
        # Use printf for better formatting and color support
        if [ -t 1 ]; then
            # If stdout is a terminal, use colors
            printf "%b[%s] %s%s: %s%b\n" \
                "${COLORS[WHITE]}" "$timestamp" \
                "$color" "$level" \
                "${COLORS[RESET]}" "$message" \
                "${COLORS[RESET]}"
        else
            # If stdout is not a terminal (e.g., being piped), don't use colors
            printf "[%s] %s: %s\n" "$timestamp" "$level" "$message"
        fi
    fi
}

# Log functions for different levels
log_debug() { log "DEBUG" "$*"; }
log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*" >&2; } 