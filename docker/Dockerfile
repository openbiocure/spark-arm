# Use an official ARM64 base image with OpenJDK
FROM arm64v8/openjdk:17-slim

# Set Spark and Hadoop versions
ENV SPARK_VERSION=3.5.1 \
    HADOOP_VERSION=3 \
    SPARK_HOME=/opt/spark \
    PATH=${PATH}:/opt/spark/bin:/opt/spark/sbin

# Install necessary dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    tar \
    bash \
    procps \
    tini && \
    rm -rf /var/lib/apt/lists/*

# Download and install Spark
RUN curl -fSL "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" -o /tmp/spark.tgz && \
    tar -xf /tmp/spark.tgz -C /opt/ && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} && \
    rm /tmp/spark.tgz && \
    # Create necessary directories
    mkdir -p ${SPARK_HOME}/logs && \
    # Verify installation
    ls -la ${SPARK_HOME}/sbin/start-master.sh && \
    chmod +x ${SPARK_HOME}/sbin/start-master.sh && \
    chmod +x ${SPARK_HOME}/sbin/start-worker.sh

# Set the working directory
WORKDIR $SPARK_HOME

# Create and set up the start scripts
RUN cat > /start-spark.sh <<'EOF'
#!/bin/bash
set -e

echo "=== Starting Spark Master ==="
echo "SPARK_HOME: $SPARK_HOME"
echo "PATH: $PATH"

# Start the Spark master
/opt/spark/sbin/start-master.sh --host $(hostname) --port 7077 --webui-port 8080

# Wait for the log file to be created
LOG_FILE=""
while [ -z "$LOG_FILE" ]; do
    sleep 1
    LOG_FILE=$(find /opt/spark/logs -name "spark--org.apache.spark.deploy.master.Master-1-*.out" -type f | head -n 1)
done

echo "=== Spark Master Logs ==="
echo "Tailing log file: $LOG_FILE"
exec tail -f "$LOG_FILE"
EOF

RUN cat > /start-worker.sh <<'EOF'
#!/bin/bash
set -e

echo "=== Starting Spark Worker ==="
echo "SPARK_HOME: $SPARK_HOME"
echo "PATH: $PATH"
echo "SPARK_MASTER_HOST: $SPARK_MASTER_HOST"
echo "SPARK_MASTER_PORT: $SPARK_MASTER_PORT"
echo "SPARK_WORKER_CORES: $SPARK_WORKER_CORES"
echo "SPARK_WORKER_MEMORY: $SPARK_WORKER_MEMORY"

# Start the Spark worker
/opt/spark/sbin/start-worker.sh spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT} --cores $SPARK_WORKER_CORES --memory $SPARK_WORKER_MEMORY

# Wait for the log file to be created
LOG_FILE=""
while [ -z "$LOG_FILE" ]; do
    sleep 1
    LOG_FILE=$(find /opt/spark/logs -name "spark--org.apache.spark.deploy.worker.Worker-*.out" -type f | head -n 1)
done

echo "=== Spark Worker Logs ==="
echo "Tailing log file: $LOG_FILE"
exec tail -f "$LOG_FILE"
EOF

# Make the start scripts executable
RUN chmod +x /start-spark.sh /start-worker.sh

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start-spark.sh"] 