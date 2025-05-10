# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Traefik ingress support with configurable options
  - SSL/TLS support
  - Basic authentication middleware
  - CORS middleware
  - Rate limiting middleware
- GitHub Actions workflow for automated ARM64 container builds
- Container publishing to GitHub Container Registry (ghcr.io/openbiocure)
- Compile Hadoop native libraries from source for ARM64
- Health checks for master and worker pods
- Persistent logging with local-path storage
- Service discovery improvements using DNS names
- Resource management and limits configuration

### Changed
- Updated Hadoop version to 3.3.6
- Updated image repository to use ghcr.io/openbiocure
- Optimized image pull policy to IfNotPresent
- Simplified service discovery configuration
- Updated documentation to reflect ARM64 support

### Fixed
- Native library compilation for ARM64 architecture
- Worker-to-master communication using proper service names
- Storage configuration using local-path provider
- Resource specifications in Kubernetes manifests

## [0.3.0] - 2024-05-09

### Added
- Initial Helm chart for Spark on ARM
- Basic Docker configuration for ARM64
- Master and worker deployment templates
- Service configurations for cluster communication
- Basic resource management

### Changed
- Configured worker nodes with 2 cores and 2GB memory
- Set up master node with proper resource allocation

### Fixed
- Initial service discovery setup
- Basic logging configuration 