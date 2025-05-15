name := "spark-arm-tests"
version := "1.0.0"
scalaVersion := "2.13.13"

// Allow using a newer scala-library version
allowUnsafeScalaLibUpgrade := true

// Load versions from environment variables
val sparkVersion = sys.env.getOrElse("SPARK_VERSION", "3.5.5")
val deltaVersion = sys.env.getOrElse("DELTA_VERSION", "3.3.1")
val hadoopVersion = sys.env.getOrElse("HADOOP_VERSION", "3.3.6")

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-sql" % sparkVersion,
  "org.apache.spark" %% "spark-hive" % sparkVersion,      // <-- this line is missing!
  "io.delta" %% "delta-spark" % deltaVersion,
  "org.apache.hadoop" % "hadoop-aws" % hadoopVersion,
  "org.apache.hadoop" % "hadoop-client" % hadoopVersion,
  "org.scalatest" %% "scalatest" % "3.2.17",
  "org.postgresql" % "postgresql" % "42.7.2"
)

// Add Delta Lake repository
resolvers += "Delta Lake" at "https://maven.delta.io/"

// Assembly plugin settings
assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
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