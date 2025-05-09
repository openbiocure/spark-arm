# Spark on ARM

A Kubernetes-based Apache Spark deployment optimized for ARM64 architecture.

## Features

- 🚀 Optimized for ARM64 architecture
- 🔄 Automatic container builds via GitHub Actions
- 📦 Kubernetes-ready with Helm charts
- 🔧 Native Hadoop library support
- 📊 Resource management and monitoring
- 🔍 Health checks and logging

## Quick Start

```bash
# Install the Helm chart
helm install spark-arm ./spark-arm --namespace spark --create-namespace

# Verify the deployment
kubectl get pods -n spark
```

## Container Builds

The Docker image is automatically built and published to GitHub Container Registry (ghcr.io) when:
- Changes are pushed to the `docker/` directory
- Changes are made to the GitHub Actions workflow

### Image Tags
- `latest`: Latest build from main branch
- `sha-<commit>`: Specific commit build
- `<branch-name>`: Branch-specific build
- `v*`: Release tags

## Configuration

Key configurations in `values.yaml`:
```yaml
# Worker configuration
worker:
  replicaCount: 2
  cores: "2"
  memory: "2048m"

# Storage configuration
storage:
  className: local-path
  size: 10Gi
```

## Development

### Local Build
```bash
docker build -t spark-arm:local docker/
```

### CI/CD Pipeline
- Automated builds via GitHub Actions
- Multi-arch support (ARM64)
- Caching for faster builds
- Automated tagging and metadata

## License

Apache License 2.0