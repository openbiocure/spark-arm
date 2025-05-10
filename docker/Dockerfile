# Build stage for Hadoop native libraries
FROM eclipse-temurin:17-jdk-jammy AS hadoop-builder

# Set environment variables
ENV HADOOP_VERSION=3.3.6

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    libssl-dev \
    maven \
    pkg-config \
    zlib1g-dev \
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
FROM eclipse-temurin:17-jdk-jammy

# Set environment variables
ENV SPARK_VERSION=3.5.1
ENV HADOOP_VERSION=3.3.6
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin
ENV HADOOP_HOME=/opt/hadoop
ENV LD_LIBRARY_PATH=$HADOOP_HOME/lib/native:$LD_LIBRARY_PATH

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    netcat-openbsd \
    procps \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p ${SPARK_HOME} ${HADOOP_HOME}/lib/native

# Copy Hadoop native libraries from builder stage
COPY --from=hadoop-builder /opt/hadoop/lib/native ${HADOOP_HOME}/lib/native/

# Download and install Spark
RUN curl -fSL "https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz" -o /tmp/spark.tgz && \
    tar -xf /tmp/spark.tgz -C /opt && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop3/* ${SPARK_HOME} && \
    rm -rf /tmp/spark.tgz /opt/spark-${SPARK_VERSION}-bin-hadoop3

# Copy scripts
COPY scripts/ ${SPARK_HOME}/scripts/
RUN chmod +x ${SPARK_HOME}/scripts/*.sh

# Set working directory
WORKDIR ${SPARK_HOME}

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/opt/spark/scripts/start-spark.sh"] 