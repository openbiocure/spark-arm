# Build stage for Hadoop native libraries
FROM arm64v8/openjdk:17-slim AS hadoop-builder

# Set Hadoop version
ENV HADOOP_VERSION=3.3.6

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    zlib1g-dev \
    libssl-dev \
    libsnappy-dev \
    cmake \
    pkg-config \
    git \
    libprotobuf-dev \
    protobuf-compiler \
    maven \
    autoconf \
    libtool \
    automake \
    bison \
    flex \
    libkrb5-dev \
    libbz2-dev \
    liblz4-dev \
    libzstd-dev \
    && rm -rf /var/lib/apt/lists/*

# Build Hadoop native libraries
RUN mkdir -p /opt/hadoop/lib/native && \
    curl -fSL "https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}-src.tar.gz" -o /tmp/hadoop-src.tar.gz && \
    tar -xf /tmp/hadoop-src.tar.gz -C /tmp && \
    cd /tmp/hadoop-${HADOOP_VERSION}-src && \
    mvn clean package -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true && \
    cp /tmp/hadoop-${HADOOP_VERSION}-src/hadoop-dist/target/hadoop-${HADOOP_VERSION}/lib/native/* /opt/hadoop/lib/native/ && \
    cd / && \
    rm -rf /tmp/hadoop-src.tar.gz /tmp/hadoop-${HADOOP_VERSION}-src

# Final stage
FROM arm64v8/openjdk:17-slim

# Set environment variables
ENV SPARK_VERSION=3.5.1 \
    HADOOP_VERSION=3.3.6 \
    SPARK_HOME=/opt/spark \
    HADOOP_HOME=/opt/hadoop \
    PATH=${PATH}:/opt/spark/bin:/opt/spark/sbin \
    LD_LIBRARY_PATH=/opt/hadoop/lib/native \
    LOG_LEVEL=1 \
    SPARK_NODE_TYPE=master

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    tar \
    bash \
    procps \
    tini \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p ${SPARK_HOME}/scripts ${SPARK_HOME}/logs ${HADOOP_HOME}/lib/native

# Copy scripts
COPY scripts/start-master.sh scripts/start-worker.sh scripts/logging.sh scripts/start-spark.sh ${SPARK_HOME}/scripts/
RUN chmod +x ${SPARK_HOME}/scripts/*.sh

# Copy Hadoop native libraries from builder stage
COPY --from=hadoop-builder /opt/hadoop/lib/native ${HADOOP_HOME}/lib/native/

# Download and install Spark
RUN curl -fSL "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" -o /tmp/spark.tgz && \
    tar -xf /tmp/spark.tgz -C /opt/ && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}/* ${SPARK_HOME}/ && \
    rm /tmp/spark.tgz && \
    chmod +x ${SPARK_HOME}/sbin/start-master.sh && \
    chmod +x ${SPARK_HOME}/sbin/start-worker.sh

# Set the working directory
WORKDIR $SPARK_HOME

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/opt/spark/scripts/start-spark.sh"] 