"""Strongly-typed environment configuration for Spark."""

from dataclasses import dataclass
from typing import Optional
import os

@dataclass(frozen=True)
class SparkEnv:
    """Strongly-typed environment configuration for Spark."""
    # Master configuration
    master_host: str = os.environ.get('SPARK_MASTER_HOST', '0.0.0.0')
    master_port: int = int(os.environ.get('SPARK_MASTER_PORT', '7077'))
    master_webui_port: int = int(os.environ.get('SPARK_MASTER_WEBUI_PORT', '8080'))
    master_rest_port: int = int(os.environ.get('SPARK_MASTER_REST_PORT', '6066'))

    # Worker configuration
    worker_host: str = os.environ.get('SPARK_WORKER_HOST', '0.0.0.0')
    worker_cores: int = int(os.environ.get('SPARK_WORKER_CORES', '1'))
    worker_memory: str = os.environ.get('SPARK_WORKER_MEMORY', '1g')
    worker_webui_port: int = int(os.environ.get('SPARK_WORKER_WEBUI_PORT', '8081'))
    worker_port: int = int(os.environ.get('SPARK_WORKER_PORT', '0'))
    worker_dir: str = os.environ.get('SPARK_WORKER_DIR', '/opt/spark/work')

    # Core paths
    spark_home: str = os.environ.get('SPARK_HOME', '/opt/spark')
    spark_conf_dir: str = os.environ.get('SPARK_CONF_DIR', '/opt/spark/conf')
    spark_local_dirs: str = os.environ.get('SPARK_LOCAL_DIRS', '/opt/spark/tmp')
    java_home: str = os.environ.get('JAVA_HOME', '/opt/java/openjdk')

    # AWS/S3 configuration
    aws_endpoint_url: Optional[str] = os.environ.get('AWS_ENDPOINT_URL')
    aws_access_key_id: Optional[str] = os.environ.get('AWS_ACCESS_KEY_ID')
    aws_secret_access_key: Optional[str] = os.environ.get('AWS_SECRET_ACCESS_KEY')

    # Delta Lake configuration
    delta_log_store_class: str = os.environ.get(
        'SPARK_DELTA_LOG_STORE_CLASS',
        'org.apache.spark.sql.delta.storage.S3SingleDriverLogStore'
    )
    sql_warehouse_dir: str = os.environ.get('SPARK_SQL_WAREHOUSE_DIR', 's3a://warehouse')

    # S3A settings
    s3a_path_style_access: bool = os.environ.get('SPARK_HADOOP_FS_S3A_PATH_STYLE_ACCESS', 'true').lower() == 'true'
    s3a_connection_ssl_enabled: bool = os.environ.get('SPARK_HADOOP_FS_S3A_CONNECTION_SSL_ENABLED', 'true').lower() == 'true'

    # Hive integration
    sql_catalog_implementation: Optional[str] = os.environ.get('SPARK_SQL_CATALOG_IMPLEMENTATION')
    hive_metastore_uri: Optional[str] = os.environ.get('SPARK_HIVE_METASTORE_URI')

    @classmethod
    def load(cls) -> 'SparkEnv':
        """Load environment configuration."""
        return cls()

    def to_dict(self) -> dict:
        """Convert to dictionary for logging."""
        return {
            field: getattr(self, field)
            for field in self.__dataclass_fields__
            if not field.startswith('aws_') or getattr(self, field) is not None  # Skip empty AWS credentials
        } 