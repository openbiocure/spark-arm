# Version Compatibility

## Current Versions
- Spark: 3.5.0
- Delta Lake: 3.0.0
- Hadoop: 3.3.6
- Scala: 2.13
- AWS SDK: 1.12.262

## Version Selection Rationale

### Spark and Delta Lake Compatibility
We are using Spark 3.5.0 with Delta Lake 3.0.0 because:
1. Delta Lake 3.0.0 supports Spark 3.5.x
2. This combination provides access to the latest Spark features
3. Delta Lake 3.0.0 includes improvements in performance and stability
4. Both versions are stable and production-ready

### Dependencies
- Spark 3.5.0
  - Latest stable version
  - Includes all necessary Spark components
  - Compatible with Delta Lake 3.0.0
- Delta Lake 3.0.0
  - Latest stable version
  - Supports Spark 3.5.x
  - Includes all Delta Lake features we need
- Hadoop 3.3.6
  - Compatible with both Spark 3.5.0 and Delta Lake 3.0.0
  - Provides necessary S3 support
- AWS SDK 1.12.262
  - Required for S3 operations
  - Compatible with Hadoop 3.3.6

## Version Update Process
When updating versions:
1. Check Delta Lake compatibility matrix
2. Verify Spark version requirements
3. Test S3/MinIO operations
4. Update this document
5. Update Dockerfile
6. Test the build process
7. Verify all Spark jobs work as expected 