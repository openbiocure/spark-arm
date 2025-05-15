name := "spark-arm-tests"
version := "1.0.0"
scalaVersion := "2.12.18"

// Allow using a newer scala-library version
allowUnsafeScalaLibUpgrade := true

// Load versions from environment variables
val sparkVersion = sys.env.getOrElse("SPARK_VERSION", "3.5.5")
val deltaVersion = sys.env.getOrElse("DELTA_VERSION", "3.3.1")
val hadoopVersion = "3.3.4"  // Using the version that Spark 3.5.5 was built with
val awsSdkVersion = sys.env.getOrElse("AWS_SDK_VERSION", "1.12.262")

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-sql" % sparkVersion,
  "org.apache.spark" %% "spark-hive" % sparkVersion,
  "org.apache.spark" %% "spark-core" % sparkVersion,
  "io.delta" %% "delta-spark" % deltaVersion,
  // Hadoop dependencies with consistent versions
  "org.apache.hadoop" % "hadoop-aws" % hadoopVersion,
  "org.apache.hadoop" % "hadoop-client" % hadoopVersion,
  "org.apache.hadoop" % "hadoop-common" % hadoopVersion,
  "org.apache.hadoop" % "hadoop-client-api" % hadoopVersion,
  "org.apache.hadoop" % "hadoop-client-runtime" % hadoopVersion,
  "org.apache.hadoop" % "hadoop-mapreduce-client-core" % hadoopVersion,
  // AWS SDK dependencies
  "com.amazonaws" % "aws-java-sdk-bundle" % awsSdkVersion,
  "com.amazonaws" % "aws-java-sdk-s3" % awsSdkVersion,
  "org.apache.hadoop" % "hadoop-cloud-storage" % hadoopVersion,
  // Other dependencies
  "org.scalatest" %% "scalatest" % "3.2.17",
  "org.postgresql" % "postgresql" % "42.7.2"
)

// Add Delta Lake repository
resolvers += "Delta Lake" at "https://packages.delta.io/maven"

// Assembly plugin settings
assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case PathList("META-INF", "services", xs @ _*) => MergeStrategy.filterDistinctLines
  case PathList("META-INF", "versions", "9", "module-info.class") => MergeStrategy.discard
  case x => MergeStrategy.first
}

// Exclude Scala library from assembly
assembly / assemblyOption := (assembly / assemblyOption).value.withIncludeScala(false)

// Test settings
Test / parallelExecution := false
Test / logBuffered := false

// Add assembly plugin
enablePlugins(AssemblyPlugin)

// Apply JVM args for both Compile and Test runs
Compile / run / fork := true
Test / fork := true

// Ensure fork is enabled for all run configurations including runMain
run / fork := true
runMain / fork := true

// Apply javaOptions in all necessary scopes
Compile / run / javaOptions ++= Seq(
  "--add-exports=java.base/sun.nio.ch=ALL-UNNAMED",
  "-Dspark.worker.cleanup.enabled=false"
)

Test / javaOptions ++= Seq(
  "--add-exports=java.base/sun.nio.ch=ALL-UNNAMED",
  "--add-opens=java.base/java.nio=ALL-UNNAMED",
  "-Dspark.worker.cleanup.enabled=false"
)

// Apply javaOptions to all run configurations including runMain
run / javaOptions ++= Seq(
  "-Dspark.worker.cleanup.enabled=false"
)

runMain / javaOptions ++= Seq(
  "-Dspark.worker.cleanup.enabled=false",
  "--add-exports=java.base/sun.nio.ch=ALL-UNNAMED"
)