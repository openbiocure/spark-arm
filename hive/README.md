# Hive Service

This directory contains the configuration and scripts for running Apache Hive as a standalone service.

## Directory Structure

```
hive/
├── Dockerfile              # Hive service container definition
├── README.md              # This file
├── conf/                  # Configuration files
│   ├── hive-site.xml     # Hive configuration
│   ├── core-site.xml     # Hadoop core configuration
│   └── hdfs-site.xml     # Hadoop HDFS configuration
└── scripts/               # Installation and startup scripts
    ├── install-hadoop.sh  # Hadoop installation script
    ├── install-hive.sh    # Hive installation script
    ├── start-hive.sh      # Hive startup script
    └── logging.sh         # Logging utilities
```

## Building the Container

```bash
# Build the container
docker build -t hive-service \
  --build-arg HADOOP_VERSION=3.3.6 \
  --build-arg HIVE_VERSION=4.0.1 \
  --build-arg POSTGRES_VERSION=42.7.3 \
  .
```

## Running the Container

```bash
docker run -it --rm \
  -v /tmp/hive-logs:/opt/hive/logs \
  -e HIVE_METASTORE_HOST=your-postgres-host \
  -e HIVE_METASTORE_PORT=5432 \
  -e HIVE_METASTORE_USER=hive \
  -e HIVE_METASTORE_PASSWORD=hive \
  -e HIVE_SERVER2_HOST=0.0.0.0 \
  -e HIVE_SERVER2_PORT=10000 \
  -e HIVE_WAREHOUSE_DIR=s3a://your-bucket/warehouse \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  -e AWS_ENDPOINT_URL=http://your-s3-endpoint:9000 \
  hive-service
```

## Environment Variables

Required environment variables:
- `HIVE_METASTORE_HOST`: PostgreSQL host for Hive metastore
- `HIVE_METASTORE_PORT`: PostgreSQL port (default: 5432)
- `HIVE_METASTORE_USER`: PostgreSQL user for Hive
- `HIVE_METASTORE_PASSWORD`: PostgreSQL password for Hive
- `HIVE_SERVER2_HOST`: Host to bind HiveServer2 (default: 0.0.0.0)
- `HIVE_SERVER2_PORT`: Port for HiveServer2 (default: 10000)
- `HIVE_WAREHOUSE_DIR`: S3 location for Hive warehouse

Optional environment variables:
- `AWS_ACCESS_KEY_ID`: S3 access key
- `AWS_SECRET_ACCESS_KEY`: S3 secret key
- `AWS_ENDPOINT_URL`: S3 endpoint URL

## Configuration Files

### hive-site.xml
Main Hive configuration file containing:
- Metastore connection settings
- Server2 settings
- Warehouse location
- Execution engine settings

### core-site.xml
Hadoop core configuration for:
- S3 filesystem settings
- AWS credentials
- Other Hadoop core properties

### hdfs-site.xml
HDFS configuration (minimal in our case since we're using S3) 