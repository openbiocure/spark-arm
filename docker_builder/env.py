"""Environment variable management for Spark components."""

from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import Field, field_validator


class SparkEnv(BaseSettings):
    """Spark environment configuration."""

    # Node configuration
    SPARK_NODE_TYPE: str = Field(
        default="master",
        description="Type of Spark node (master/worker)",
        pattern="^(master|worker)$",
    )

    # Master configuration
    SPARK_MASTER_HOST: str = Field(
        default="0.0.0.0", description="Host address for the master"
    )
    SPARK_MASTER_PORT: int = Field(
        default=7077,
        description="Port for the master"
    )
    SPARK_MASTER_WEBUI_PORT: int = Field(
        default=8080,
        description="Web UI port for the master"
    )
    SPARK_MASTER_REST_PORT: int = Field(
        default=6066,
        description="REST port for the master"
    )

    # Worker configuration
    SPARK_MASTER_URL: Optional[str] = Field(
        default=None, description="URL of the Spark master"
    )
    SPARK_WORKER_HOST: str = Field(
        default="0.0.0.0", description="Host address for the worker"
    )
    SPARK_WORKER_CORES: int = Field(
        default=1,
        description="Number of cores to use"
    )
    SPARK_WORKER_MEMORY: str = Field(
        default="1g",
        description="Amount of memory to use"
    )
    SPARK_WORKER_WEBUI_PORT: int = Field(
        default=8081, description="Web UI port for the worker"
    )
    SPARK_WORKER_PORT: int = Field(
        default=0,
        description="Port for the worker"
    )
    SPARK_WORKER_DIR: str = Field(
        default="/opt/spark/work",
        description="Directory for worker files"
    )

    # Core paths
    SPARK_HOME: str = Field(
        default="/opt/spark", description="Spark installation directory"
    )
    SPARK_CONF_DIR: str = Field(
        default="/opt/spark/conf", description="Spark configuration directory"
    )
    SPARK_LOCAL_DIRS: str = Field(
        default="/opt/spark/tmp", description="Directory for temporary files"
    )
    JAVA_HOME: str = Field(
        default="/opt/java/openjdk", description="Java installation directory"
    )

    # AWS/S3 configuration
    AWS_ENDPOINT_URL: Optional[str] = Field(
        default=None, description="AWS endpoint URL (e.g., MinIO endpoint)"
    )
    AWS_ACCESS_KEY_ID: Optional[str] = Field(default=None)
    AWS_SECRET_ACCESS_KEY: Optional[str] = Field(default=None)

    # Delta Lake configuration
    SPARK_DELTA_LOG_STORE_CLASS: str = Field(
        default="org.apache.spark.sql.delta.storage.S3SingleDriverLogStore",
        description="Delta Lake log store class",
    )
    SPARK_SQL_WAREHOUSE_DIR: str = Field(
        default="s3a://warehouse", description="Spark SQL warehouse directory"
    )

    # S3A settings
    SPARK_HADOOP_FS_S3A_PATH_STYLE_ACCESS: bool = Field(
        default=True, description="Use path-style access for S3A"
    )
    SPARK_HADOOP_FS_S3A_CONNECTION_SSL_ENABLED: bool = Field(
        default=True, description="Enable SSL for S3A connections"
    )

    # Hive integration
    SPARK_SQL_CATALOG_IMPLEMENTATION: Optional[str] = Field(
        default=None, description="Spark SQL catalog implementation"
    )
    SPARK_HIVE_METASTORE_URI: Optional[str] = Field(
        default=None, description="Hive metastore URI"
    )

    class Config:
        """Pydantic model configuration."""

        env_file = ".env"
        case_sensitive = True
        extra = "ignore"

    @field_validator("SPARK_NODE_TYPE")
    @classmethod
    def validate_node_type(cls, v: str) -> str:
        """Validate SPARK_NODE_TYPE."""
        if v in {"master", "worker"}:
            return v
        raise ValueError("SPARK_NODE_TYPE must be either 'master' or 'worker'")

    @field_validator("AWS_ACCESS_KEY_ID")
    @classmethod
    def validate_aws_access_key(cls, v: str, info) -> str:
        """Validate AWS credentials."""
        if not v:
            raise ValueError("AWS_ACCESS_KEY_ID must not be empty")
        return v

    @field_validator("AWS_SECRET_ACCESS_KEY")
    @classmethod
    def validate_aws_secret(cls, v: str, info) -> str:
        """Validate AWS credentials."""
        if not v:
            raise ValueError("AWS_SECRET_ACCESS_KEY must not be empty")
        return v

    def to_env_dict(self) -> dict:
        """Convert settings to environment variable dictionary."""
        items = self.model_dump().items()
        return {k: str(v) for k, v in items if v is not None}

    @classmethod
    def load_spark_env(cls) -> "SparkEnv":
        """Load Spark environment configuration."""
        return cls()
