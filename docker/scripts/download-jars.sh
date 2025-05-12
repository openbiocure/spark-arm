#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Function to verify URL exists
verify_url() {
    local url=$1
    log_info "Verifying URL exists: $url"
    if curl -s --head --fail "$url" > /dev/null; then
        log_info "URL exists and is accessible"
        return 0
    else
        log_error "URL does not exist or is not accessible: $url"
        return 1
    fi
}

# Function to download and verify JARs
download_and_verify_jar() {
    local url=$1
    local output=$2
    local expected_size=${3:-0}
    
    # Verify URL exists before attempting download
    if ! verify_url "$url"; then
        log_error "JAR not available at URL: $url"
        return 1
    fi
    
    log_info "Downloading $url to $output"
    if curl -fSL "$url" -o "$output"; then
        if [ -f "$output" ]; then
            local actual_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
            if [ "$actual_size" -gt 0 ]; then
                log_info "Successfully downloaded $(basename $output) ($actual_size bytes)"
                return 0
            fi
        fi
    fi
    log_error "Failed to download or verify $url"
    return 1
}

# Download Delta Lake JARs
download_delta_jars() {
    local spark_home=$1
    
    log_info "=== Downloading Delta Lake JARs ==="
    
    # Verify URL exists before downloading
    if ! verify_url "$DELTA_URL_TEMPLATE"; then
        log_error "Delta Lake JAR not available"
        return 1
    fi
    
    # Download Delta Lake JAR
    local jar_name=$(basename "$DELTA_URL_TEMPLATE")
    download_and_verify_jar \
        "$DELTA_URL_TEMPLATE" \
        "${spark_home}/jars/${jar_name}" || {
            log_error "Failed to download Delta Lake JAR"
            exit 1
        }
}

# Download AWS SDK JARs
download_aws_jars() {
    local spark_home=$1
    
    log_info "=== Downloading AWS SDK JARs ==="
    
    # Verify URL exists before downloading
    if ! verify_url "$AWS_BUNDLE_URL_TEMPLATE"; then
        log_error "AWS SDK Bundle JAR not available"
        return 1
    fi
    
    # Download AWS SDK Bundle JAR
    local bundle_name=$(basename "$AWS_BUNDLE_URL_TEMPLATE")
    
    download_and_verify_jar \
        "$AWS_BUNDLE_URL_TEMPLATE" \
        "${spark_home}/jars/${bundle_name}" || exit 1
}

# Verify JARs are present
verify_jars() {
    local spark_home=$1
    
    log_info "=== Verifying JARs ==="
    
    log_info "Delta Lake JARs:"
    ls -l ${spark_home}/jars/delta-*.jar || log_error "No Delta Lake JARs found"
    
    log_info "AWS SDK JARs:"
    ls -l ${spark_home}/jars/aws-java-sdk-bundle-*.jar || log_error "No AWS SDK Bundle JAR found"
}

# Main function to download all JARs
download_all_jars() {
    local spark_home=${SPARK_HOME:-/opt/spark}
    
    # Create jars directory if it doesn't exist
    mkdir -p "${spark_home}/jars"
    
    # Download all JARs
    download_delta_jars "$spark_home"
    download_aws_jars "$spark_home"
    
    # Verify all JARs
    verify_jars "$spark_home"
}

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_all_jars
fi 