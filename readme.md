[![Build and Push ARM64 Docker Image](https://github.com/openbiocure/spark-arm/actions/workflows/docker-build.yml/badge.svg)](https://github.com/openbiocure/spark-arm/actions/workflows/docker-build.yml)
[![Build and Push Hive Image](https://github.com/openbiocure/spark-arm/actions/workflows/hive-build.yml/badge.svg)](https://github.com/openbiocure/spark-arm/actions/workflows/hive-build.yml)

# Spark Cluster for ARM64

A production-ready Apache Spark cluster configuration for ARM64 architecture, featuring Docker containers and Kubernetes deployment.

## Features

- 🐳 Multi-stage Docker build optimized for ARM64
- 🔄 Automated builds with GitHub Actions for both Spark and Hive images
- 🔒 Traefik ingress with TLS support
- 📊 Enhanced logging with rotation
- 🏥 Health checks and monitoring
- 🔄 Stateful master node
- 📦 Helm chart for easy deployment
- 🔧 Makefile for common tasks
- ✅ Stable release with verified master-worker connectivity
- 🐝 Integrated Hive Metastore and HiveServer2 support
- 🔄 Automated Hive image builds and deployments

## Current Status

The project is now in a stable state with:
- Verified master-worker connectivity
- Proper service discovery
- Resource cleanup
- Health monitoring
- Persistent logging
- Functional Hive Metastore and HiveServer2 services
- Integrated Spark-Hive connectivity

## Prerequisites

### Basic Requirements
- Docker with ARM64 support
- Kubernetes cluster
- Helm 3.x
- kubectl
- make

### Testing Prerequisites
To run the local testing environment, you need:

1. Required JARs:
   ```bash
   # Create directories for JARs
   mkdir -p $HOME/spark-hive-jars $HOME/spark-extra-jars
   
   # Download Hive JARs (version 2.3.9)
   curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-common/2.3.9/hive-common-2.3.9.jar -o $HOME/spark-hive-jars/
   curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-cli/2.3.9/hive-cli-2.3.9.jar -o $HOME/spark-hive-jars/
   curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-metastore/2.3.9/hive-metastore-2.3.9.jar -o $HOME/spark-hive-jars/
   curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-exec/2.3.9/hive-exec-2.3.9-core.jar -o $HOME/spark-hive-jars/
   curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-serde/2.3.9/hive-serde-2.3.9.jar -o $HOME/spark-hive-jars/
   curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-jdbc/2.3.9/hive-jdbc-2.3.9.jar -o $HOME/spark-hive-jars/
   
   # Download AWS JARs
   curl -L https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar -o $HOME/spark-extra-jars/
   curl -L https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar -o $HOME/spark-extra-jars/
   ```

2. Required Services:
   - PostgreSQL server (for Hive metastore)
   - MinIO or S3-compatible storage
   - Apache Spark (for spark-shell)
   - Beeline client (for Hive Server2 testing)

3. Network Access:
   - PostgreSQL port (default: 5432)
   - MinIO/S3 port (default: 9000)
   - Hive Server2 port (default: 10000)

4. Environment Variables:
   ```bash
   # PostgreSQL
   export POSTGRES_HOST=your-postgres-host
   export POSTGRES_PORT=5432
   export POSTGRES_USER=hive
   export POSTGRES_PASSWORD=hive
   
   # MinIO/S3
   export AWS_ENDPOINT_URL=http://your-minio-host:9000
   export AWS_ACCESS_KEY_ID=your-access-key
   export AWS_SECRET_ACCESS_KEY=your-secret-key
   export MINIO_BUCKET=your-bucket-name
   ```

5. Testing Tools:
   - netcat (for port testing)
   - curl (for downloading JARs)
   - beeline (for Hive Server2 testing)
   - sbt (for Scala testing)

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/openbiocure/spark-arm.git
cd spark-arm
```

2. Use the stable release:
```bash
git checkout stable
```

3. Build and deploy:
```bash
make all
```

Or deploy step by step:
```bash
make build    # Build Docker image
make push     # Push to registry
make deploy   # Deploy to Kubernetes
```

## Configuration

### Environment Variables

The following environment variables can be configured in `spark-arm/values.yaml`:

```yaml
# Master configuration
master:
  resources:
    limits:
      cpu: "1"
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "512Mi"

# Worker configuration
worker:
  replicaCount: 2
  cores: "2"
  memory: "2048m"
  resources:
    limits:
      cpu: "2"
      memory: "2Gi"
    requests:
      cpu: "1"
      memory: "1Gi"
```

### Storage

The cluster uses persistent storage for logs:
```yaml
storage:
  className: local-path
  size: 10Gi
  accessMode: ReadWriteOnce
```

### Ingress

Traefik ingress is configurable with TLS:
```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
    traefik.ingress.kubernetes.io/router.tls: "true"
```

## Development

### Available Make Commands

```bash
make build        # Build Spark Docker image
make build-hive   # Build Hive Docker image
make push         # Push Spark image to registry
make push-hive    # Push Hive image to registry
make deploy       # Deploy to Kubernetes
make undeploy     # Remove deployment
make logs         # View logs
make test         # Test cluster readiness
make clean        # Clean up artifacts
make help         # Show all commands
```

### Building Locally

```bash
# Build Spark for ARM64
docker build --platform linux/arm64 -t spark-arm:latest -f docker/Dockerfile .

# Build Hive for ARM64
docker build --platform linux/arm64 -t hive-arm:latest -f hive/Dockerfile hive
```

### Testing

```bash
# Test cluster readiness
make test

# View logs
make logs
```

## Testing Environment

### Local Testing with Spark Shell and Hive

To test the Spark and Hive integration locally, you can use the following spark-shell command:

```bash
spark-shell \
  --master "local[*]" \
  --jars \
$HOME/spark-hive-jars/hive-common-2.3.9.jar,\
$HOME/spark-hive-jars/hive-cli-2.3.9.jar,\
$HOME/spark-hive-jars/hive-metastore-2.3.9.jar,\
$HOME/spark-hive-jars/hive-exec-2.3.9-core.jar,\
$HOME/spark-hive-jars/hive-serde-2.3.9.jar,\
$HOME/spark-hive-jars/hive-jdbc-2.3.9.jar,\
$HOME/spark-extra-jars/hadoop-aws-3.3.4.jar,\
$HOME/spark-extra-jars/aws-java-sdk-bundle-1.12.262.jar \
  --conf spark.sql.catalogImplementation=hive \
  --conf javax.jdo.option.ConnectionURL=jdbc:postgresql://172.16.14.112:5432/hive \
  --conf javax.jdo.option.ConnectionDriverName=org.postgresql.Driver \
  --conf javax.jdo.option.ConnectionUserName=hive \
  --conf javax.jdo.option.ConnectionPassword=hive \
  --conf spark.sql.warehouse.dir=s3a://test/warehouse \
  --conf spark.hadoop.fs.s3a.endpoint=http://172.16.14.201:9000 \
  --conf spark.hadoop.fs.s3a.access.key=iglIu8yZXZRFipZQDEFI \
  --conf spark.hadoop.fs.s3a.secret.key=J0lqSKgQKKJBfnNnwMHBhinFy1iMxmKGIKh4h6oP \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
```

### Testing Connectivity

Once the spark-shell is running, you can test the connectivity with the following commands:

1. Test Hive Metastore Connection:
```scala
// List all databases
spark.sql("SHOW DATABASES").show()

// Create a test database
spark.sql("CREATE DATABASE IF NOT EXISTS test_db")

// Use the test database
spark.sql("USE test_db")

// Create a test table
spark.sql("""
  CREATE TABLE IF NOT EXISTS test_table (
    id INT,
    name STRING,
    value DOUBLE
  )
""")

// Insert some test data
spark.sql("""
  INSERT INTO test_table VALUES 
  (1, 'test1', 1.1),
  (2, 'test2', 2.2)
""")

// Query the table
spark.sql("SELECT * FROM test_table").show()
```

2. Test S3/MinIO Connection:
```scala
// List files in the warehouse directory
spark.sql("SHOW CREATE TABLE test_table").show(false)

// Check if we can write to S3
spark.sql("""
  CREATE TABLE IF NOT EXISTS s3_test (
    id INT,
    data STRING
  ) LOCATION 's3a://test/warehouse/s3_test'
""")

// Insert data to S3
spark.sql("""
  INSERT INTO s3_test VALUES 
  (1, 's3_test1'),
  (2, 's3_test2')
""")

// Verify data in S3
spark.sql("SELECT * FROM s3_test").show()
```

3. Test Hive Server2 Connection (from another terminal):
```bash
# Using beeline client
beeline -u jdbc:hive2://localhost:10000

# Or using the Hive CLI
hive --service cli
```

If you encounter any connection issues:
1. Verify PostgreSQL is running and accessible: `nc -zv 172.16.14.112 5432`
2. Verify MinIO is running and accessible: `nc -zv 172.16.14.201 9000`
3. Check the logs: `tail -f /opt/spark/logs/spark-*.log`
4. Verify all required JARs are present in the specified directories

## Architecture

- **Master Node**: StatefulSet with single replica
- **Worker Nodes**: Deployment with configurable replicas
- **Storage**: PersistentVolume for logs
- **Networking**: Traefik ingress with TLS
- **Monitoring**: Health checks and logging

## Pod Scheduling
The Spark cluster is deployed using StatefulSets with the following characteristics:
- Master pod runs as a single replica
- Worker pods run with configurable replicas (default: 3)
- Pods are scheduled on Linux nodes using a basic node selector
- No affinity rules or topology constraints are enforced, allowing flexible pod placement
- Each pod has its own persistent volume for logs

## Health Checks
The pods use the following probe configurations for health monitoring:
- Startup Probe:
  - Master: 5 seconds initial delay
  - Worker: 10 seconds initial delay
  - 3-second period
  - 2-second timeout
- Liveness/Readiness Probes:
  - 10 seconds initial delay
  - 5-second period
  - 3-second timeout
  - 3 failure threshold

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Apache Spark
- Apache Hadoop
- Kubernetes
- Traefik
- GitHub Actions