# Spark Cluster for ARM64

A production-ready Apache Spark cluster configuration for ARM64 architecture, featuring Docker containers and Kubernetes deployment.

## Features

- 🐳 Multi-stage Docker build optimized for ARM64
- 🔄 Automated builds with GitHub Actions
- 🔒 Traefik ingress with TLS support
- 📊 Enhanced logging with rotation
- 🏥 Health checks and monitoring
- 🔄 Stateful master node
- 📦 Helm chart for easy deployment
- 🔧 Makefile for common tasks
- ✅ Stable release with verified master-worker connectivity

## Current Status

The project is now in a stable state with:
- Verified master-worker connectivity
- Proper service discovery
- Resource cleanup
- Health monitoring
- Persistent logging

## Prerequisites

- Docker with ARM64 support
- Kubernetes cluster
- Helm 3.x
- kubectl
- make

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
make build     # Build Docker image
make push      # Push to registry
make deploy    # Deploy to Kubernetes
make undeploy  # Remove deployment
make logs      # View logs
make test      # Test cluster readiness
make clean     # Clean up artifacts
make help      # Show all commands
```

### Building Locally

```bash
# Build for ARM64
docker build --platform linux/arm64 -t spark-arm:latest -f docker/Dockerfile .
```

### Testing

```bash
# Test cluster readiness
make test

# View logs
make logs
```

## Architecture

- **Master Node**: StatefulSet with single replica
- **Worker Nodes**: Deployment with configurable replicas
- **Storage**: PersistentVolume for logs
- **Networking**: Traefik ingress with TLS
- **Monitoring**: Health checks and logging

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