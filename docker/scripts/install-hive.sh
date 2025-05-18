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

# Function to download and install Hive
download_and_install_hive() {
    local hive_version=$1
    local hive_home=$2
    local max_attempts=3
    local attempt=1
    
    log_info "Starting Hive download process for version ${hive_version}"
    
    # Verify URL exists before attempting download
    if ! verify_url "$HIVE_URL_TEMPLATE"; then
        log_error "Hive version ${hive_version} is not available at the expected URL"
        return 1
    fi
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt ${attempt} of ${max_attempts} to download Hive..."
        
        if curl -fSL --retry 3 --retry-delay 5 \
            "$HIVE_URL_TEMPLATE" \
            -o /tmp/hive.tar.gz; then
            
            log_info "Download successful"
            
            # Verify download
            log_info "Verifying download..."
            local file_size=$(stat -f%z /tmp/hive.tar.gz 2>/dev/null || stat -c%s /tmp/hive.tar.gz 2>/dev/null)
            log_info "Downloaded file size: ${file_size} bytes"
            
            if [ "$file_size" -lt 1000000 ]; then
                log_error "Downloaded file seems too small (${file_size} bytes)"
                rm -f /tmp/hive.tar.gz
                attempt=$((attempt + 1))
                continue
            fi
            
            # Extract and install
            log_info "Extracting Hive archive..."
            tar -xf /tmp/hive.tar.gz -C /opt
            
            log_info "Moving files to ${hive_home}..."
            mv /opt/apache-hive-${hive_version}-bin/* "${hive_home}"
            
            log_info "Cleaning up..."
            rm -rf /tmp/hive.tar.gz /opt/apache-hive-${hive_version}-bin
            
            log_info "Hive installation completed successfully"
            return 0
        else
            log_error "Download failed on attempt ${attempt}"
            rm -f /tmp/hive.tar.gz
            
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

# Function to configure Hive
configure_hive() {
    local hive_home=$1
    
    log_info "=== Configuring Hive ==="
    
    # Copy Hive configuration
    log_info "Copying Hive configuration..."
    cp /opt/spark/conf/hive-site.xml ${hive_home}/conf/
    
    # Create Hive directories
    log_info "Creating Hive directories..."
    mkdir -p ${hive_home}/warehouse ${hive_home}/tmp
    chmod -R 777 ${hive_home}/warehouse ${hive_home}/tmp
    
    # Add Hive to Spark's classpath
    log_info "Adding Hive to Spark's classpath..."
    ln -sf ${hive_home}/lib/*.jar ${SPARK_HOME}/jars/
    
    log_info "Hive configuration completed successfully"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <hive_version> <hive_home>"
        exit 1
    fi
    
    download_and_install_hive "$1" "$2"
    configure_hive "$2"
fi 