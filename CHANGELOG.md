# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2024-04-11

### Added
- Multi-stage Docker build for optimized image size
- Enhanced logging system with log rotation
- Improved error handling in startup scripts
- Health checks for master and worker nodes
- Traefik ingress support with TLS configuration
- GitHub Actions workflow for automated builds
- Makefile for common development tasks

### Changed
- Converted master node to StatefulSet for better reliability
- Simplified Helm chart configuration
- Removed redundant node type configuration
- Hardcoded SPARK_MASTER_HOST in deployment templates
- Updated base image to eclipse-temurin:17-jdk-jammy
- Improved Dockerfile structure and build process

### Fixed
- Fixed curl dependency in Hadoop builder stage
- Fixed Dockerfile keyword casing
- Fixed worker-to-master communication issues
- Fixed log persistence configuration

## [0.2.0] - 2024-04-10

### Added
- Initial Helm chart implementation
- Basic Docker configuration
- ARM64 architecture support
- Persistent volume configuration
- Service discovery setup

### Changed
- Updated Spark version to 3.5.1
- Updated Hadoop version to 3.3.6

## [0.1.0] - 2024-04-09

### Added
- Initial project setup
- Basic Docker configuration
- ARM64 architecture support 