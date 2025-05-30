# syntax=docker/dockerfile:1.4

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

# Stage 1: URL verification (lightweight)
FROM eclipse-temurin:17-jdk-jammy AS url-verifier
# Create scripts directory
RUN mkdir -p /opt/spark/scripts

# Copy only the scripts needed for verification
COPY docker/scripts/logging.sh /opt/spark/scripts/
COPY docker/scripts/verify-urls.sh docker/scripts/install-verifier-deps.sh /tmp/
RUN chmod +x /tmp/*.sh /opt/spark/scripts/*.sh

# Set version environment variables for verification
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

# Export all variables to environment
ENV SPARK_VERSION="${SPARK_VERSION}" \
    HADOOP_VERSION="${HADOOP_VERSION}" \
    DELTA_VERSION="${DELTA_VERSION}" \
    AWS_SDK_VERSION="${AWS_SDK_VERSION}" \
    SCALA_VERSION="${SCALA_VERSION}" \
    SPARK_URL_TEMPLATE="${SPARK_URL_TEMPLATE}" \
    HADOOP_URL_TEMPLATE="${HADOOP_URL_TEMPLATE}" \
    DELTA_URL_TEMPLATE="${DELTA_URL_TEMPLATE}" \
    AWS_BUNDLE_URL_TEMPLATE="${AWS_BUNDLE_URL_TEMPLATE}" \
    AWS_S3_URL_TEMPLATE="${AWS_S3_URL_TEMPLATE}"

# Debug output for environment variables
RUN echo "Debug: Environment variables in url-verifier stage:"

# Install URL verification dependencies and run verification
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    /tmp/install-verifier-deps.sh && \
    /tmp/verify-urls.sh && \
    touch /tmp/urls-verified

# Stage 2: Hadoop native libraries builder
FROM eclipse-temurin:17-jdk-jammy AS hadoop-builder
ARG HADOOP_VERSION
ENV HADOOP_HOME=/opt/hadoop

# Create scripts directory and copy logging script
RUN mkdir -p /opt/spark/scripts
COPY --from=url-verifier /opt/spark/scripts/logging.sh /opt/spark/scripts/
COPY docker/scripts/install-hadoop-native.sh /tmp/
RUN chmod +x /tmp/*.sh /opt/spark/scripts/*.sh

# Install Hadoop native libraries
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    /tmp/install-hadoop-native.sh ${HADOOP_VERSION} ${HADOOP_HOME}

# Stage 3: Final runtime image
FROM eclipse-temurin:17-jdk-jammy

# Common environment variables
ENV SPARK_HOME=/opt/spark \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/spark/bin \
    HADOOP_HOME=/opt/hadoop \
    LD_LIBRARY_PATH=/opt/hadoop/lib/native \
    SPARK_CLASSPATH=/opt/spark/jars/*

# Copy verification marker and native libraries
COPY --from=url-verifier /tmp/urls-verified /tmp/
COPY --from=hadoop-builder /opt/hadoop/lib/native ${HADOOP_HOME}/lib/native/

# Copy all scripts
COPY docker/scripts/ ${SPARK_HOME}/scripts/
RUN chmod +x ${SPARK_HOME}/scripts/*.sh

# Set version environment variables
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

# Install system dependencies and create user
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        netcat-openbsd \
        procps \
        tini \
        coreutils \
        bash \
        && rm -rf /var/lib/apt/lists/* && \
    # Create user and directories
    groupadd -r spark && \
    useradd -r -g spark spark && \
    # Create directories with proper permissions
    mkdir -p ${SPARK_HOME} ${HADOOP_HOME}/lib/native ${SPARK_HOME}/jars ${SPARK_HOME}/logs && \
    # Set ownership of directories
    chown -R spark:spark ${SPARK_HOME} ${HADOOP_HOME} && \
    # Set permissions for log directories
    chmod 777 ${SPARK_HOME}/logs && \
    # Ensure spark user has access to essential commands
    chmod -R 755 /usr/bin/bash /usr/bin/date /usr/bin/mkdir && \
    # Verify essential commands are available and accessible
    su - spark -c "which bash" && \
    su - spark -c "which date" && \
    su - spark -c "which mkdir" && \
    # Verify log directories are accessible
    su - spark -c "test -w ${SPARK_HOME}/logs"

# Download and install Spark
RUN --mount=type=cache,target=/tmp/downloads \
    ${SPARK_HOME}/scripts/download-spark.sh ${SPARK_VERSION} ${SPARK_HOME}

# Download all required JARs in parallel
RUN --mount=type=cache,target=/tmp/downloads \
    ${SPARK_HOME}/scripts/download-jars.sh

# Create spark-defaults.conf
RUN ${SPARK_HOME}/scripts/create-spark-defaults.sh

# Set working directory
WORKDIR ${SPARK_HOME}

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/opt/spark/scripts/start-spark.sh"] 