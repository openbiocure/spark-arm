# Define build arguments for versions
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG DELTA_VERSION
ARG AWS_SDK_VERSION
ARG SCALA_VERSION
ARG SPARK_URL_TEMPLATE
ARG HADOOP_URL_TEMPLATE
ARG DELTA_URL_TEMPLATE
ARG AWS_BUNDLE_URL_TEMPLATE
ARG AWS_S3_URL_TEMPLATE

# Base stage with common environment variables
FROM eclipse-temurin:17-jdk-jammy AS base
# Common environment variables that don't depend on ARGs
ENV SPARK_HOME=/opt/spark \
    PATH=$PATH:/opt/spark/bin \
    HADOOP_HOME=/opt/hadoop \
    LD_LIBRARY_PATH=/opt/hadoop/lib/native \
    SPARK_CLASSPATH=/opt/spark/jars/*

# URL verification stage
FROM base AS url-verifier
# Redeclare ARGs used in this stage
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG DELTA_VERSION
ARG AWS_SDK_VERSION
ARG SCALA_VERSION

# Install curl for URL verification
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy and run verification script
COPY docker/scripts/verify-urls.sh /verify-urls.sh
RUN chmod +x /verify-urls.sh && /verify-urls.sh

# Build stage for Hadoop native libraries
FROM base AS hadoop-builder
# Redeclare ARGs used in this stage
ARG HADOOP_VERSION

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download pre-built Hadoop binary
RUN mkdir -p /opt/hadoop/lib/native && \
    curl -fSL "https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" -o /tmp/hadoop.tar.gz && \
    tar -xf /tmp/hadoop.tar.gz -C /tmp && \
    cp -r /tmp/hadoop-${HADOOP_VERSION}/lib/native/* /opt/hadoop/lib/native/ && \
    rm -rf /tmp/hadoop.tar.gz /tmp/hadoop-${HADOOP_VERSION}

# Final stage
FROM base
# Redeclare all ARGs used in this stage
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG DELTA_VERSION
ARG AWS_SDK_VERSION
ARG SCALA_VERSION
ARG SPARK_URL_TEMPLATE
ARG HADOOP_URL_TEMPLATE
ARG DELTA_URL_TEMPLATE
ARG AWS_BUNDLE_URL_TEMPLATE
ARG AWS_S3_URL_TEMPLATE

# Set version environment variables
ENV SPARK_VERSION=${SPARK_VERSION} \
    HADOOP_VERSION=${HADOOP_VERSION} \
    DELTA_VERSION=${DELTA_VERSION} \
    AWS_SDK_VERSION=${AWS_SDK_VERSION} \
    SCALA_VERSION=${SCALA_VERSION} \
    SPARK_URL_TEMPLATE=${SPARK_URL_TEMPLATE} \
    HADOOP_URL_TEMPLATE=${HADOOP_URL_TEMPLATE} \
    DELTA_URL_TEMPLATE=${DELTA_URL_TEMPLATE} \
    AWS_BUNDLE_URL_TEMPLATE=${AWS_BUNDLE_URL_TEMPLATE} \
    AWS_S3_URL_TEMPLATE=${AWS_S3_URL_TEMPLATE}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    netcat-openbsd \
    procps \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p ${SPARK_HOME} ${HADOOP_HOME}/lib/native ${SPARK_HOME}/jars ${SPARK_HOME}/logs

# Copy Hadoop native libraries from builder stage
COPY --from=hadoop-builder /opt/hadoop/lib/native ${HADOOP_HOME}/lib/native/

# Copy scripts
COPY docker/scripts/ ${SPARK_HOME}/scripts/
RUN chmod +x ${SPARK_HOME}/scripts/*.sh

# Download and install Spark
RUN ${SPARK_HOME}/scripts/download-spark.sh ${SPARK_VERSION} ${SPARK_HOME}

# Download all required JARs
RUN ${SPARK_HOME}/scripts/download-jars.sh

# Create spark-defaults.conf
RUN ${SPARK_HOME}/scripts/create-spark-defaults.sh

# Set working directory
WORKDIR ${SPARK_HOME}

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/opt/spark/scripts/start-spark.sh"] 