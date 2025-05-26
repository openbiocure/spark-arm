#!/bin/bash
set -euo pipefail

# Source the logging library
source $HIVE_HOME/scripts/logging.sh

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

# Function to download and install Hadoop
download_and_install_hadoop() {
    local hadoop_version=$1
    local hadoop_home=$2
    local max_attempts=3
    local attempt=1
    
    log_info "Starting Hadoop download process for version ${hadoop_version}"
    log_info "Target installation directory: ${hadoop_home}"
    
    # Construct the download URL
    local hadoop_url="https://dlcdn.apache.org/hadoop/common/hadoop-${hadoop_version}/hadoop-${hadoop_version}.tar.gz"
    log_info "Hadoop download URL: ${hadoop_url}"
    
    # Verify URL exists before attempting download
    if ! verify_url "$hadoop_url"; then
        log_error "Hadoop version ${hadoop_version} is not available at the expected URL"
        return 1
    fi
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt ${attempt} of ${max_attempts} to download Hadoop..."
        
        if curl -fSL --retry 3 --retry-delay 5 \
            "$hadoop_url" \
            -o /tmp/hadoop.tar.gz; then
            
            log_info "Download successful"
            
            # Verify download
            log_info "Verifying download..."
            local file_size=$(stat -f%z /tmp/hadoop.tar.gz 2>/dev/null || stat -c%s /tmp/hadoop.tar.gz 2>/dev/null)
            log_info "Downloaded file size: ${file_size} bytes"
            
            if [ "$file_size" -lt 1000000 ]; then
                log_error "Downloaded file seems too small (${file_size} bytes)"
                rm -f /tmp/hadoop.tar.gz
                attempt=$((attempt + 1))
                continue
            fi
            
            # Extract and install
            log_info "Extracting Hadoop archive to /opt..."
            tar -xf /tmp/hadoop.tar.gz -C /opt
            
            log_info "Checking extracted directory..."
            if [ ! -d "/opt/hadoop-${hadoop_version}" ]; then
                log_error "Extraction failed - directory /opt/hadoop-${hadoop_version} not found"
                ls -la /opt/
                return 1
            fi
            
            log_info "Moving files to ${hadoop_home}..."
            if [ ! -d "${hadoop_home}" ]; then
                log_error "Target directory ${hadoop_home} does not exist"
                return 1
            fi
            
            # List contents before move
            log_info "Contents of /opt/hadoop-${hadoop_version}:"
            ls -la "/opt/hadoop-${hadoop_version}"
            
            mv "/opt/hadoop-${hadoop_version}"/* "${hadoop_home}"
            
            # Verify installation
            log_info "Verifying installation..."
            if [ ! -f "${hadoop_home}/bin/hadoop" ]; then
                log_error "Hadoop binary not found at ${hadoop_home}/bin/hadoop"
                ls -la "${hadoop_home}/bin/"
                return 1
            fi
            
            log_info "Contents of ${hadoop_home}:"
            ls -la "${hadoop_home}"
            
            log_info "Cleaning up..."
            rm -rf /tmp/hadoop.tar.gz "/opt/hadoop-${hadoop_version}"
            
            # Clean up conflicting SLF4J binding
            log_info "Cleaning up conflicting SLF4J bindings..."
            find "${hadoop_home}/share/hadoop/common/lib" -name "slf4j-reload4j-*.jar" -delete
            log_info "Removed slf4j-reload4j binding to prevent logging conflicts"
            
            log_info "Hadoop installation completed successfully"
            return 0
        else
            log_error "Download failed on attempt ${attempt}"
            rm -f /tmp/hadoop.tar.gz
            
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
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <hadoop_version> <hadoop_home>"
        exit 1
    fi
    
    log_info "Starting Hadoop installation with version $1 to directory $2"
    download_and_install_hadoop "$1" "$2"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Hadoop installation failed with exit code $exit_code"
        exit $exit_code
    fi
fi 