# Upgrade to Spark 4.0.0 with Hadoop 3.3.6

## Current Situation
- Using Spark 3.5.5 with built-in Hadoop 3.3.4 libraries
- Hadoop 3.3.6 is available in Apache's main mirrors
- Experiencing ClassNotFoundException with PrefetchingStatistics due to version mismatch
- Hive metastore running separately with PostgreSQL
- Delta Lake integration in place

## Upgrade Plan

### 1. Version Updates
- [ ] Update versions.sh:
  ```bash
  SPARK_VERSION="4.0.0"
  HADOOP_VERSION="3.3.6"  # Already set, but now will be compatible
  DELTA_VERSION="3.0.0"   # Verify compatibility with Spark 4.0.0
  SCALA_VERSION="2.13"    # Verify if still compatible
  ```

### 2. Docker Image Changes
- [ ] Verify all URLs in docker/scripts/verify-urls.sh
- [ ] Test Hadoop 3.3.6 native libraries build in hadoop-builder stage
- [ ] Update any Spark-specific configurations in docker/conf/
- [ ] Test image build process with new versions

### 3. Hive Integration
- [ ] Verify Hive metastore compatibility with Spark 4.0.0
- [ ] Test Hive JAR versions:
  - hive-common
  - hive-cli
  - hive-metastore
  - hive-exec
  - hive-serde
  - hive-jdbc
- [ ] Test Hive metastore connection
- [ ] Verify Hive SQL compatibility
- [ ] Test Hive table operations

### 4. Delta Lake
- [ ] Verify Delta Lake 3.0.0 compatibility with Spark 4.0.0
- [ ] Test Delta Lake operations:
  - Table creation
  - Data writing
  - Data reading
  - Schema evolution
  - Time travel
  - Merge operations

### 5. Testing Requirements
- [ ] Unit tests for Spark operations
- [ ] Integration tests for:
  - S3/MinIO connectivity
  - Hive metastore operations
  - Delta Lake operations
  - Spark SQL queries
- [ ] Performance testing
- [ ] End-to-end workflow testing

### 6. Documentation Updates
- [ ] Update version information in README.md
- [ ] Document any breaking changes
- [ ] Update configuration examples
- [ ] Add upgrade notes for future reference

### 7. Rollback Plan
- [ ] Document current working configuration
- [ ] Create backup of current Docker images
- [ ] Prepare rollback scripts
- [ ] Test rollback procedure

## No Impact Areas
- Hive service (runs independently)
- PostgreSQL database
- MinIO/S3 storage
- Basic Spark cluster architecture

## Success Criteria
- [ ] All Spark operations work with Hadoop 3.3.6
- [ ] No ClassNotFoundException errors
- [ ] Hive metastore connection works
- [ ] Delta Lake operations work
- [ ] All existing Spark jobs run successfully
- [ ] Performance meets or exceeds current levels

## Future Considerations
- Monitor Spark 4.0.0 release notes for any issues
- Plan for future Delta Lake updates
- Consider Hive version upgrade in future
- Document any new features available in Spark 4.0.0
