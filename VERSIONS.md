# Version Compatibility

## Current Versions
- PySpark: 3.4.2
- Delta Spark: 2.4.0
- Hadoop: 3.3.6
- Scala: 2.13
- AWS SDK: 1.12.262

## Version Selection Rationale

### PySpark and Delta Spark Compatibility
We are using PySpark 3.4.2 with Delta Spark 2.4.0 because:
1. Delta Spark 2.4.0 requires PySpark >=3.4.0 and <3.5.0
2. This is a stable, tested combination
3. While PySpark 3.5.5 is available, Delta Spark 2.4.0 does not support it yet
4. PySpark 3.4.2 is the latest version in the 3.4.x series that is compatible with Delta Spark 2.4.0

### Future Considerations
- When Delta Spark releases a version that supports PySpark 3.5.x, we can upgrade
- Current Delta Spark versions available (as of May 2024):
  - Latest stable: 2.4.0
  - Latest development: Not yet available for PySpark 3.5.x

### Dependencies
- PySpark 3.4.2
  - Compatible with Delta Spark 2.4.0
  - Includes all necessary Spark components
  - Stable and well-tested
- Delta Spark 2.4.0
  - Latest stable version
  - Requires PySpark >=3.4.0 and <3.5.0
  - Includes all Delta Lake features we need
- Hadoop 3.3.6
  - Compatible with both PySpark 3.4.2 and Delta Spark 2.4.0
  - Provides necessary S3 support
- AWS SDK 1.12.262
  - Required for S3 operations
  - Compatible with Hadoop 3.3.6

## Version Update Process
When updating versions:
1. Check Delta Spark compatibility matrix
2. Verify PySpark version requirements
3. Test S3/MinIO operations
4. Update this document
5. Update Dockerfile
6. Test the build process
7. Verify all Spark jobs work as expected 