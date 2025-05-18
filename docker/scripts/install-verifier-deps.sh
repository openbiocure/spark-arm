#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Function to check if a package is installed
is_package_installed() {
    local package=$1
    # Check both dpkg and which for the package
    if dpkg -l | grep -q "^ii  ${package} " || which "${package}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Function to install URL verification dependencies
install_verifier_dependencies() {
    log_info "=== Installing URL Verification Dependencies ==="
    
    # List of required packages
    local packages=("curl")
    
    log_info "Updating package lists..."
    if ! apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Filter out already installed packages
    local packages_to_install=()
    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            packages_to_install+=("$package")
        else
            log_info "Package $package is already installed"
        fi
    done
    
    # Only install if there are packages to install
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log_info "Installing required packages: ${packages_to_install[*]}"
        if ! apt-get install -y "${packages_to_install[@]}"; then
            log_error "Failed to install required packages"
            return 1
        fi
    else
        log_info "All required packages are already installed"
    fi
    
    log_info "Cleaning up package lists..."
    if ! rm -rf /var/lib/apt/lists/*; then
        log_warn "Failed to clean up package lists, but continuing"
    fi
    
    # Verify all packages are available
    log_info "Verifying package availability..."
    for package in "${packages[@]}"; do
        if is_package_installed "$package"; then
            log_info "✓ ${package} is available"
        else
            log_error "Package ${package} is not available"
            return 1
        fi
    done
    
    log_info "URL verification dependencies installation completed successfully"
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_verifier_dependencies
fi 