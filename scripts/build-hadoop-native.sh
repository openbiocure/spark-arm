#!/bin/bash
set -euo pipefail

# Source logging if available
if [ -f "${SPARK_HOME:-/opt/spark}/scripts/logging.sh" ]; then
    source "${SPARK_HOME}/scripts/logging.sh"
    init_logging
else
    # Basic logging functions if not available
    log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"; }
    log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"; exit 1; }
    log_warn() { echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $1"; }
fi

# Configuration
HADOOP_VERSION="3.3.6"
BUILD_DIR="/tmp/hadoop-native-build"
DIST_DIR="${BUILD_DIR}/dist"
REQUIRED_TOOLS=("git" "mvn" "cmake" "gcc" "g++" "make")

# Function to check required tools
check_requirements() {
    log_info "Checking build requirements..."
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "$tool is required but not installed"
        fi
    done
    
    # Check Java version
    if ! java -version 2>&1 | grep -q "version \"17"; then
        log_error "Java 17 is required but not found"
    fi
    
    # Check Maven version
    if ! mvn --version | grep -q "Apache Maven 3.8"; then
        log_warn "Maven 3.8+ is recommended"
    fi
    
    # Check available memory
    local mem_total=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$mem_total" -lt 4096 ]; then
        log_warn "Less than 4GB of RAM available. Build might fail or be very slow"
    fi
}

# Function to clone and prepare Hadoop source
prepare_source() {
    log_info "Preparing Hadoop source code..."
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    
    if [ ! -d "hadoop" ]; then
        log_info "Cloning Hadoop repository..."
        git clone https://github.com/apache/hadoop.git
    fi
    
    cd hadoop
    git fetch --tags
    git checkout "rel/release-${HADOOP_VERSION}"
    
    # Apply ARM64 specific patches if needed
    # TODO: Add any necessary patches for ARM64 support
}

# Function to build native libraries
build_native_libs() {
    log_info "Building native libraries..."
    cd "${BUILD_DIR}/hadoop"
    
    # Set environment variables for ARM64
    export CFLAGS="-march=armv8-a -O2"
    export CXXFLAGS="-march=armv8-a -O2"
    export MAVEN_OPTS="-Xmx2g"
    
    # First build without native libraries to ensure all dependencies are downloaded
    log_info "Building Hadoop without native libraries first..."
    mvn clean package \
        -Pdist \
        -DskipTests \
        -Dmaven.javadoc.skip=true \
        -Dtar \
        -DskipNative
    
    # Now build native libraries with specific flags
    log_info "Building native libraries (this may take a while)..."
    mvn clean package \
        -Pdist,native \
        -DskipTests \
        -Dmaven.javadoc.skip=true \
        -Drequire.snappy \
        -Drequire.zstd \
        -Drequire.openssl \
        -Drequire.bzip2 \
        -DskipFuse \
        -DskipValgrind \
        -DskipTestLibhadoop \
        -Dtar \
        -Dcmake.compiler=GCC \
        -Dcmake.compiler.version=11 \
        -Dcmake.compiler.path=/usr/bin/gcc \
        -Dcmake.c.compiler=/usr/bin/gcc \
        -Dcmake.cxx.compiler=/usr/bin/g++ \
        -Dcmake.c.flags="-march=armv8-a -O2" \
        -Dcmake.cxx.flags="-march=armv8-a -O2"
    
    # Create distribution directory
    mkdir -p "${DIST_DIR}"
    
    # Copy built libraries
    log_info "Copying built libraries..."
    cp hadoop-dist/target/hadoop-${HADOOP_VERSION}/lib/native/* "${DIST_DIR}/"
    
    # Verify the libraries
    log_info "Verifying built libraries..."
    local arm64_count=0
    local total_count=0
    
    for lib in "${DIST_DIR}"/*.so; do
        if [ -f "$lib" ]; then
            total_count=$((total_count + 1))
            if file "$lib" | grep -q "ARM aarch64"; then
                log_info "✓ $lib is ARM64 compatible"
                arm64_count=$((arm64_count + 1))
            else
                log_warn "! $lib is not ARM64 compatible"
            fi
        fi
    done
    
    if [ "$arm64_count" -eq 0 ]; then
        log_error "No ARM64 compatible libraries were built"
    elif [ "$arm64_count" -lt "$total_count" ]; then
        log_warn "Only $arm64_count out of $total_count libraries are ARM64 compatible"
    else
        log_info "All $total_count libraries are ARM64 compatible"
    fi
}

# Function to create installation package
create_package() {
    log_info "Creating installation package..."
    cd "${BUILD_DIR}"
    
    # Create a tarball of the native libraries
    tar -czf "hadoop-${HADOOP_VERSION}-native-arm64.tar.gz" -C dist .
    
    # Create a checksum file
    sha256sum "hadoop-${HADOOP_VERSION}-native-arm64.tar.gz" > "hadoop-${HADOOP_VERSION}-native-arm64.tar.gz.sha256"
    
    log_info "Package created: ${BUILD_DIR}/hadoop-${HADOOP_VERSION}-native-arm64.tar.gz"
    log_info "Checksum file: ${BUILD_DIR}/hadoop-${HADOOP_VERSION}-native-arm64.tar.gz.sha256"
    log_info "To install, extract to /opt/hadoop/lib/native/"
}

# Function to clean up build artifacts
cleanup() {
    if [ "${KEEP_BUILD:-false}" != "true" ]; then
        log_info "Cleaning up build artifacts..."
        rm -rf "${BUILD_DIR}/hadoop"
    else
        log_info "Keeping build artifacts in ${BUILD_DIR}"
    fi
}

# Main execution
main() {
    log_info "Starting Hadoop native libraries build for ARM64"
    log_info "Hadoop version: ${HADOOP_VERSION}"
    log_info "Build directory: ${BUILD_DIR}"
    log_info "Distribution directory: ${DIST_DIR}"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-build)
                KEEP_BUILD=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --keep-build    Keep build artifacts after completion"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_requirements
    prepare_source
    build_native_libs
    create_package
    cleanup
    
    log_info "Build completed successfully"
    log_info "Native libraries are in: ${DIST_DIR}"
    log_info "Installation package: ${BUILD_DIR}/hadoop-${HADOOP_VERSION}-native-arm64.tar.gz"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 