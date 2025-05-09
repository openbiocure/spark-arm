# Spark on ARM (Apple Silicon/Raspberry Pi)

This repository contains Docker and Kubernetes configurations for running Apache Spark on ARM architecture.

## Building the Image

Build the Spark Docker image for ARM:

```sh
docker build ./docker -t openbiocure/spark-arm:v0.2
```

## Testing Locally with Docker

### 1. Start the Spark Master

```sh
docker run -it --rm -p 8080:8080 -p 7077:7077 --name spark-master openbiocure/spark-arm:v0.2
```

This will:
- Start a Spark master node
- Expose the Spark master port (7077)
- Expose the Web UI port (8080)
- You can access the Web UI at http://localhost:8080

### 2. Start a Spark Worker

In a new terminal, start a worker that connects to the master:

```sh
docker run -it --rm \
  --link spark-master \
  -e SPARK_MASTER_HOST=spark-master \
  -e SPARK_MASTER_PORT=7077 \
  -e SPARK_WORKER_CORES=2 \
  -e SPARK_WORKER_MEMORY=2g \
  --name spark-worker \
  openbiocure/spark-arm:v0.2 \
  /start-worker.sh
```

This will:
- Start a Spark worker
- Connect to the master using Docker networking
- Allocate 2 cores and 2GB memory to the worker
- You can see the worker in the master's Web UI

## Running on Kubernetes

### 1. Install the Helm Chart

```sh
helm install spark-arm ./spark-arm --namespace spark --create-namespace
```

This will deploy:
- A Spark master node
- Configured number of worker nodes (default: 2)
- Required services and configurations

### 2. Access the Spark UI

```sh
kubectl port-forward -n spark svc/spark-arm 8080:8080
```

Then visit http://localhost:8080 to see the Spark cluster status.

## Configuration

### Docker Environment Variables

Workers can be configured with these environment variables:
- `SPARK_MASTER_HOST`: Hostname of the Spark master
- `SPARK_MASTER_PORT`: Port of the Spark master (default: 7077)
- `SPARK_WORKER_CORES`: Number of cores to allocate (e.g., "2")
- `SPARK_WORKER_MEMORY`: Amount of memory to allocate (e.g., "2g")

### Helm Chart Values

Key configurations in `values.yaml`:
```yaml
# Master configuration
replicaCount: 1

# Worker configuration
worker:
  replicaCount: 2
  cores: "2"
  memory: "2g"
  resources:
    limits:
      cpu: 2000m
      memory: 2560Mi
```

## Ports

- 7077: Spark master port
- 8080: Spark master Web UI
- 8081: Spark worker Web UI