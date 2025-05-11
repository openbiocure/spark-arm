# Build stage for Hadoop native libraries
FROM eclipse-temurin:17-jdk-jammy AS hadoop-builder

# Set environment variables
ENV HADOOP_VERSION=3.3.6

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
FROM eclipse-temurin:17-jdk-jammy

# Set environment variables
# Using Spark 3.5.0 with Delta Lake 3.0.0 for latest features
ENV SPARK_VERSION=3.5.0
ENV HADOOP_VERSION=3.3.6
ENV DELTA_VERSION=3.0.0
ENV AWS_SDK_VERSION=1.12.262
ENV SCALA_VERSION=2.13
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin
ENV HADOOP_HOME=/opt/hadoop
ENV LD_LIBRARY_PATH=/opt/hadoop/lib/native
ENV SPARK_CLASSPATH=/opt/spark/jars/*

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    netcat-openbsd \
    procps \
    tini \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Set Python environment variables
ENV PYTHONPATH=/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.7-src.zip
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    pyspark==${SPARK_VERSION} \
    delta-spark==${DELTA_VERSION} \
    pyarrow \
    pandas \
    numpy

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

# Create spark-defaults.conf with necessary configurations
RUN echo "spark.driver.extraClassPath /opt/spark/jars/*" > ${SPARK_HOME}/conf/spark-defaults.conf && \
    echo "spark.executor.extraClassPath /opt/spark/jars/*" >> ${SPARK_HOME}/conf/spark-defaults.conf && \
    echo "spark.sql.extensions io.delta.sql.DeltaSparkSessionExtension" >> ${SPARK_HOME}/conf/spark-defaults.conf && \
    echo "spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog" >> ${SPARK_HOME}/conf/spark-defaults.conf

# Set working directory
WORKDIR ${SPARK_HOME}

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/opt/spark/scripts/start-spark.sh"] 