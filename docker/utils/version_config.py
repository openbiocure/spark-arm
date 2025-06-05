"""Version configuration management for Spark components."""

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Any, Optional
import yaml
from pydantic import BaseModel, Field


@dataclass
class DeltaVersions:
    """Delta Lake version configuration."""
    core: str
    spark: str
    storage: str


@dataclass
class ScalaVersions:
    """Scala version configuration."""
    version: str
    full_version: str


@dataclass
class JavaVersions:
    """Java version configuration."""
    version: str
    distribution: str
    full_version: str


@dataclass
class SparkConfig:
    """Spark component configuration."""
    home: str
    delta_log_store: str
    s3a: Dict[str, bool]


@dataclass
class HadoopConfig:
    """Hadoop component configuration."""
    home: str


@dataclass
class HiveMetastoreConfig:
    """Hive metastore configuration."""
    host: str
    port: int


@dataclass
class HiveServer2Config:
    """Hive server2 configuration."""
    port: int
    thrift_bind_host: str


@dataclass
class HiveConfig:
    """Hive component configuration."""
    metastore: HiveMetastoreConfig
    server2: HiveServer2Config


@dataclass
class PostgresConfig:
    """Postgres component configuration."""
    host: str
    port: int
    database: str


@dataclass
class MinioConfig:
    """Minio component configuration."""
    endpoint: str
    bucket: str


@dataclass
class ComponentConfigs:
    """All component configurations."""
    spark: SparkConfig
    hadoop: HadoopConfig
    hive: HiveConfig
    postgres: PostgresConfig
    minio: MinioConfig


class VersionConfig:
    """Complete version configuration."""
    
    def __init__(
        self,
        spark_version: str,
        hadoop_version: str,
        delta_versions: DeltaVersions,
        hive_version: str,
        postgres_version: str,
        aws_sdk_version: str,
        scala_versions: ScalaVersions,
        java_versions: JavaVersions,
        components: ComponentConfigs
    ):
        """Initialize version configuration."""
        self.spark_version = spark_version
        self.hadoop_version = hadoop_version
        self.delta_versions = delta_versions
        self.hive_version = hive_version
        self.postgres_version = postgres_version
        self.aws_sdk_version = aws_sdk_version
        self.scala_versions = scala_versions
        self.java_versions = java_versions
        self.components = components

    @classmethod
    def load(cls, config_path: Optional[Path] = None) -> "VersionConfig":
        """Load version configuration from YAML file."""
        if config_path is None:
            config_path = Path(__file__).parent.parent / "configs" / "versions.yaml"
        
        if not config_path.exists():
            raise ValueError(f"Version config not found at {config_path}")
        
        try:
            with open(config_path) as f:
                config = yaml.safe_load(f)
                if not config:
                    raise ValueError("Version config file is empty")
                
                versions = config['versions']
                components = config['components']
                
                return cls(
                    spark_version=versions['spark'],
                    hadoop_version=versions['hadoop'],
                    delta_versions=DeltaVersions(**versions['delta']),
                    hive_version=versions['hive'],
                    postgres_version=versions['postgres'],
                    aws_sdk_version=versions['aws_sdk'],
                    scala_versions=ScalaVersions(**versions['scala']),
                    java_versions=JavaVersions(**versions['java']),
                    components=ComponentConfigs(
                        spark=SparkConfig(**components['spark']),
                        hadoop=HadoopConfig(**components['hadoop']),
                        hive=HiveConfig(
                            metastore=HiveMetastoreConfig(**components['hive']['metastore']),
                            server2=HiveServer2Config(**components['hive']['server2'])
                        ),
                        postgres=PostgresConfig(**components['postgres']),
                        minio=MinioConfig(**components['minio'])
                    )
                )
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML in version config: {e}")
        except Exception as e:
            raise RuntimeError(f"Failed to load version config: {e}")

    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary."""
        return {
            'versions': {
                'spark': self.spark_version,
                'hadoop': self.hadoop_version,
                'delta': {
                    'core': self.delta_versions.core,
                    'spark': self.delta_versions.spark,
                    'storage': self.delta_versions.storage
                },
                'hive': self.hive_version,
                'postgres': self.postgres_version,
                'aws_sdk': self.aws_sdk_version,
                'scala': {
                    'version': self.scala_versions.version,
                    'full_version': self.scala_versions.full_version
                },
                'java': {
                    'version': self.java_versions.version,
                    'distribution': self.java_versions.distribution,
                    'full_version': self.java_versions.full_version
                }
            },
            'components': {
                'spark': {
                    'home': self.components.spark.home,
                    'delta_log_store': self.components.spark.delta_log_store,
                    's3a': self.components.spark.s3a
                },
                'hadoop': {
                    'home': self.components.hadoop.home
                },
                'hive': {
                    'metastore': {
                        'host': self.components.hive.metastore.host,
                        'port': self.components.hive.metastore.port
                    },
                    'server2': {
                        'port': self.components.hive.server2.port,
                        'thrift_bind_host': self.components.hive.server2.thrift_bind_host
                    }
                },
                'postgres': {
                    'host': self.components.postgres.host,
                    'port': self.components.postgres.port,
                    'database': self.components.postgres.database
                },
                'minio': {
                    'endpoint': self.components.minio.endpoint,
                    'bucket': self.components.minio.bucket
                }
            }
        }

    def get_version(self, component: str) -> str:
        """Get version for a component.
        
        Args:
            component: Component name (e.g., 'spark', 'hadoop')
            
        Returns:
            Component version string.
        """
        if component == "delta":
            return self.delta_versions.core
        return str(self.versions.get(component, ""))

    def get_component_config(self, component: str) -> Dict[str, Any]:
        """Get configuration for a component.
        
        Args:
            component: Component name (e.g., 'spark', 'hadoop')
            
        Returns:
            Component configuration dictionary.
        """
        return self.components.model_dump().get(component, {}) 