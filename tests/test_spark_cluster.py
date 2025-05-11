from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType
import os
import time

def create_spark_session():
    """Create a Spark session with all necessary configurations."""
    return (SparkSession.builder
            .appName("SparkClusterTest")
            .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
            .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
            .getOrCreate())

def test_basic_spark(spark):
    """Test basic Spark functionality."""
    print("\n=== Testing Basic Spark Functionality ===")
    
    # Create a simple DataFrame
    data = [("Alice", 1), ("Bob", 2), ("Charlie", 3)]
    schema = StructType([
        StructField("name", StringType(), True),
        StructField("age", IntegerType(), True)
    ])
    df = spark.createDataFrame(data, schema)
    
    # Test DataFrame operations
    print("Created DataFrame:")
    df.show()
    
    # Test SQL
    df.createOrReplaceTempView("people")
    result = spark.sql("SELECT * FROM people WHERE age > 1")
    print("\nSQL Query Result:")
    result.show()
    
    return True

def test_minio_connectivity(spark):
    """Test MinIO connectivity and basic S3 operations."""
    print("\n=== Testing MinIO Connectivity ===")
    
    # Create a test DataFrame
    data = [("test1", 1), ("test2", 2)]
    df = spark.createDataFrame(data, ["key", "value"])
    
    # Get bucket name from environment
    bucket = os.getenv("MINIO_BUCKET", "spark-data")
    test_path = f"s3a://{bucket}/test/minio_test"
    
    # Write to MinIO
    print(f"Writing test data to {test_path}")
    df.write.mode("overwrite").parquet(test_path)
    
    # Read from MinIO
    print("Reading test data from MinIO")
    read_df = spark.read.parquet(test_path)
    print("Data read from MinIO:")
    read_df.show()
    
    return True

def test_hive_metastore(spark):
    """Test Hive metastore connectivity and operations."""
    print("\n=== Testing Hive Metastore ===")
    
    # Create a test table
    table_name = "test_hive_table"
    data = [("hive1", 1), ("hive2", 2)]
    df = spark.createDataFrame(data, ["name", "value"])
    
    # Write to Hive
    print(f"Creating Hive table: {table_name}")
    df.write.mode("overwrite").saveAsTable(table_name)
    
    # Read from Hive
    print("Reading from Hive table")
    result = spark.sql(f"SELECT * FROM {table_name}")
    print("Data from Hive table:")
    result.show()
    
    return True

def test_delta_lake(spark):
    """Test Delta Lake functionality."""
    print("\n=== Testing Delta Lake ===")
    
    # Get bucket name from environment
    bucket = os.getenv("MINIO_BUCKET", "spark-data")
    delta_path = f"s3a://{bucket}/delta/test_delta"
    
    # Create initial data
    data = [("delta1", 1), ("delta2", 2)]
    df = spark.createDataFrame(data, ["name", "value"])
    
    # Write as Delta table
    print(f"Creating Delta table at {delta_path}")
    df.write.format("delta").mode("overwrite").save(delta_path)
    
    # Read Delta table
    print("Reading Delta table")
    delta_df = spark.read.format("delta").load(delta_path)
    print("Initial Delta table data:")
    delta_df.show()
    
    # Perform an update
    print("Performing Delta table update")
    new_data = [("delta3", 3), ("delta4", 4)]
    update_df = spark.createDataFrame(new_data, ["name", "value"])
    update_df.write.format("delta").mode("append").save(delta_path)
    
    # Read updated data
    print("Reading updated Delta table")
    updated_df = spark.read.format("delta").load(delta_path)
    print("Updated Delta table data:")
    updated_df.show()
    
    return True

def main():
    """Run all tests."""
    print("Starting Spark Cluster Tests...")
    
    # Create Spark session
    spark = create_spark_session()
    
    try:
        # Run all tests
        tests = [
            ("Basic Spark", test_basic_spark),
            ("MinIO", test_minio_connectivity),
            ("Hive", test_hive_metastore),
            ("Delta Lake", test_delta_lake)
        ]
        
        results = []
        for test_name, test_func in tests:
            print(f"\nRunning {test_name} test...")
            try:
                result = test_func(spark)
                results.append((test_name, result, None))
                print(f"✓ {test_name} test passed")
            except Exception as e:
                results.append((test_name, False, str(e)))
                print(f"✗ {test_name} test failed: {str(e)}")
        
        # Print summary
        print("\n=== Test Summary ===")
        all_passed = True
        for test_name, passed, error in results:
            status = "PASSED" if passed else f"FAILED: {error}"
            print(f"{test_name}: {status}")
            if not passed:
                all_passed = False
        
        return 0 if all_passed else 1
        
    finally:
        spark.stop()

if __name__ == "__main__":
    exit(main()) 