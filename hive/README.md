# Hive Metastore Docker Image

This repository contains a Docker-based setup for Apache Hive Metastore service, optimized for ARM64 architecture. The setup provides a standalone Hive Metastore service that can be used with various data processing frameworks.

## Features

- Based on Eclipse Temurin JDK 17 (ARM64 compatible)
- Standalone Hive Metastore service
- PostgreSQL database backend
- Configurable logging with color-coded output
- Health checks and startup verification
- Volume mounts for persistent storage
- Comprehensive logging and monitoring

## Prerequisites

- Docker with ARM64 support
- PostgreSQL database (can be run as a separate container)
- Make (for using the provided Makefile)

## Directory Structure

```
hive/
├── conf/                    # Configuration files
│   ├── core-site.xml       # Hadoop core configuration
│   ├── hdfs-site.xml       # HDFS configuration
│   ├── hive-site.xml.template  # Hive configuration template
│   └── log4j2.xml          # Logging configuration
├── scripts/                 # Utility scripts
│   ├── entrypoint.sh       # Container entrypoint script
│   ├── install-hadoop.sh   # Hadoop installation script
│   ├── logging.sh          # Logging utility functions
│   └── metastore-check.sh  # Metastore health check script
├── Dockerfile              # Docker image definition
├── Makefile               # Build and management commands
├── debug.env              # Environment variables for development
└── .dockerignore         # Docker build exclusions
```

## Environment Variables

The following environment variables can be configured:

### Required Variables
- `HIVE_METASTORE_DB_HOST`: PostgreSQL host (default: postgresql)
- `HIVE_METASTORE_DB_PORT`: PostgreSQL port (default: 5432)
- `HIVE_METASTORE_DB_NAME`: Database name (default: hive)
- `HIVE_METASTORE_DB_USER`: Database user (default: hive)
- `HIVE_METASTORE_DB_PASSWORD`: Database password (default: hive)
- `HIVE_WAREHOUSE_DIR`: Hive warehouse directory
- `HIVE_SCRATCH_DIR`: Hive scratch directory

### Optional Variables
- `HIVE_METASTORE_URI`: Metastore URI (default: thrift://0.0.0.0:9083)
- `HIVE_LOG_LEVEL`: Logging level (default: INFO)
- `LOG_LEVEL`: General logging level (default: INFO)

## Usage

### Building the Image

```bash
make build
```

This will build the Docker image with the current version tag.

### Running Tests

```bash
make test
```

This will:
1. Create necessary directories
2. Start a container with the Hive Metastore service
3. Mount required volumes
4. Display container logs

### Getting a Shell

```bash
make shell
```

This will start a container with an interactive shell for debugging.

### Stopping the Test Container

```bash
make stop-test
```

### Pushing to Registry

```bash
make push
```

This will push the image to the configured registry with appropriate tags.

## Volume Mounts

The container uses the following volume mounts:
- `./warehouse:/opt/hive/warehouse`: Hive warehouse directory
- `./logs:/opt/hive/logs`: Log files directory

## Health Checks

The container includes a health check that verifies the metastore service is running on port 9083. The service also performs additional startup checks to ensure proper initialization.

## Logging

The setup includes a comprehensive logging system with:
- Color-coded output for different log levels
- Timestamp for each log entry
- Configurable log levels
- Separate log files for different components
- Terminal-aware output (colors only when appropriate)

## Development

For development and debugging:
1. Use `debug.env` for environment variables
2. Use `make shell` for interactive debugging
3. Check logs in the `logs` directory
4. Use `make test` for quick testing

## License

[Add appropriate license information]

## Contributing

[Add contribution guidelines if applicable]
