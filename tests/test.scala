// Test Spark connection and show databases
println("Testing Spark connection...")
println("Available databases:")
spark.sql("SHOW DATABASES").show(false)
println("Test completed successfully!")
:quit 