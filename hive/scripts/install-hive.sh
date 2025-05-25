#!/bin/bash

set -e

# Source logging functions
source /tmp/logging.sh

# Check arguments
if [ "$#" -ne 2 ]; then
    log_error "Usage: $0 <hive_version> <install_dir>"
    exit 1
fi

HIVE_VERSION=$1
INSTALL_DIR=$2
HIVE_URL="https://dlcdn.apache.org/hive/hive-standalone-metastore-${HIVE_VERSION}/hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz"
TEMP_DIR=$(mktemp -d)

log_info "Installing Hive ${HIVE_VERSION} to ${INSTALL_DIR}"

# Download and extract Hive
log_info "Downloading Hive from ${HIVE_URL}"
curl -L "${HIVE_URL}" -o "${TEMP_DIR}/hive.tar.gz"
tar xzf "${TEMP_DIR}/hive.tar.gz" -C "${TEMP_DIR}"

# Debug: List contents of extracted directory
log_info "Contents of extracted directory:"
ls -la "${TEMP_DIR}"
log_info "Contents of extracted tarball root:"
find "${TEMP_DIR}" -maxdepth 1 -type d

# Create necessary directories first
log_info "Creating necessary directories"
mkdir -p "${INSTALL_DIR}/lib"
mkdir -p "${INSTALL_DIR}/tmp"
mkdir -p "${INSTALL_DIR}/logs"
chmod 777 "${INSTALL_DIR}/tmp" "${INSTALL_DIR}/logs"

# Move files to install directory
log_info "Moving files to ${INSTALL_DIR}"
mv "${TEMP_DIR}/apache-hive-metastore-${HIVE_VERSION}-bin"/* "${INSTALL_DIR}/"

# Download PostgreSQL JDBC driver
POSTGRES_VERSION=${POSTGRES_VERSION:-42.7.3}
POSTGRES_URL="https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_VERSION}/postgresql-${POSTGRES_VERSION}.jar"
log_info "Downloading PostgreSQL JDBC driver from ${POSTGRES_URL}"
curl -L "${POSTGRES_URL}" -o "${INSTALL_DIR}/lib/postgresql-${POSTGRES_VERSION}.jar"

# Clean up
rm -rf "${TEMP_DIR}"

log_info "Hive installation completed successfully" 