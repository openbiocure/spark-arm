#!/bin/bash
set -euo pipefail

# Source the versions file
source /opt/spark/scripts/versions.sh

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

# Function to download and install Spark
download_and_install_spark() {
    local spark_home=$1
    local max_attempts=3
    local attempt=1
    
    # Use SPARK_VERSION from environment variable
    if [ -z "${SPARK_VERSION:-}" ]; then
        log_error "SPARK_VERSION environment variable is not set"
        return 1
    fi
    
    log_info "Starting Spark download process for version ${SPARK_VERSION}"
    
    # Use SPARK_URL_TEMPLATE from environment variable
    if [ -z "${SPARK_URL_TEMPLATE:-}" ]; then
        log_error "SPARK_URL_TEMPLATE environment variable is not set"
        return 1
    fi
    
    # Verify URL exists before attempting download
    if ! verify_url "$SPARK_URL_TEMPLATE"; then
        log_error "Spark version ${SPARK_VERSION} is not available at the expected URL"
        return 1
    fi
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt ${attempt} of ${max_attempts} to download Spark..."
        
        # Create a temporary directory in the user's home directory
        local temp_dir="${HOME}/spark-extract"
        mkdir -p "$temp_dir"
        chmod 700 "$temp_dir"
        
        if curl -fSL --retry 3 --retry-delay 5 \
            "$SPARK_URL_TEMPLATE" \
            -o "${temp_dir}/spark.tgz"; then
            
            log_info "Download successful"
            
            # Verify download
            log_info "Verifying download..."
            local file_size=$(stat -f%z "${temp_dir}/spark.tgz" 2>/dev/null || stat -c%s "${temp_dir}/spark.tgz" 2>/dev/null)
            log_info "Downloaded file size: ${file_size} bytes"
            
            if [ "$file_size" -lt 1000000 ]; then
                log_error "Downloaded file seems too small (${file_size} bytes)"
                rm -f "${temp_dir}/spark.tgz"
                attempt=$((attempt + 1))
                continue
            fi
            
            # Extract to temporary directory
            log_info "Extracting Spark archive to temporary directory..."
            cd "$temp_dir" && tar -xf spark.tgz
            
            # Get the actual directory name from the archive
            local spark_dir=$(ls -d spark-${SPARK_VERSION}-bin-hadoop3*)
            if [ ! -d "$spark_dir" ]; then
                log_error "Could not find Spark directory in archive"
                cd - > /dev/null
                rm -rf "$temp_dir"
                return 1
            fi
            
            # Move files to final location
            log_info "Moving files from ${spark_dir} to ${spark_home}..."
            mv "$spark_dir"/* "${spark_home}/"
            
            # Clean up
            log_info "Cleaning up..."
            cd - > /dev/null
            rm -rf "$temp_dir"
            
            log_info "Spark installation completed successfully"
            return 0
        else
            log_error "Download failed on attempt ${attempt}"
            rm -f "${temp_dir}/spark.tgz"
            
            if [ $attempt -eq $max_attempts ]; then
                log_error "All download attempts failed"
                return 1
            fi
            
            log_info "Waiting 5 seconds before next attempt..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    return 1
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 <spark_home>"
        exit 1
    fi
    
    download_and_install_spark "$1"
fi 