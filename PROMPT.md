You are a senior software engineer and DevOps architect. Your task is to convert an existing monolithic Dockerfile setup into a scalable, modular system that supports:

1. YAML configuration for versioning and templating
2. Environment variable overrides via a `.env` file
3. Jinja2-based Dockerfile templates
4. A `Makefile` to manage builds and rendering
5. Python-based CLI to render Dockerfiles from templates

I want to migrate what's currently in the `@docker` directory to a new modular layout under `@spark`, but I don’t want to manually write Dockerfiles. I want to use Python with Jinja2 templates and load all variables from YAML and `.env`. The system must support multiple components like Spark, Hive, etc.

Your task:
- Parse YAML + `.env`
- Generate a rendered Dockerfile from a `.j2` template
- Output to a component-specific `output/` folder
- Add a `Makefile` to support commands like `make dockerfile DOCKER_COMPONENT=spark`
- Support multiple services in `configs/` and `docker/templates/`

Do not hardcode versions. Follow the templates and config pattern. Organize it cleanly. Start now.

--- 
# The following is what we are building 

•	Spark version: 3.5.3
•	Delta Lake version: 3.3.2
•	Scala 2.12 variant: delta-spark_2.12
•	Hadoop AWS connector: hadoop-aws:3.3.2
•	Java version: OpenJDK 11 (Zulu 11.0.21 on ARM)
•	MinIO (S3-compatible object storage):
•	Used s3a:// URLs
•	fs.s3a.path.style.access=true
•	fs.s3a.connection.ssl.enabled=false
•	Delta log store override:
•	spark.delta.logStore.class=org.apache.spark.sql.delta.storage.S3SingleDriverLogStore