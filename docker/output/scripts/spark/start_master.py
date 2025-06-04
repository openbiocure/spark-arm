#!/usr/bin/env python3
"""Spark master node startup script."""

import os
import sys
import logging
import socket
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any
from dataclasses import dataclass

# Add the scripts directory to Python path
scripts_dir = Path(__file__).parent
sys.path.append(str(scripts_dir.parent.parent.parent))

try:
    from docker_builder.env import SparkEnv, load_spark_env
except ImportError:
    raise ImportError("Could not import SparkEnv. Make sure the package is installed with 'pip install -e .'")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

@dataclass
class MasterConfig:
    """Configuration for Spark master."""
    master_host: str
    master_port: int
    master_webui_port: int
    master_rest_port: int
    local_dirs: str
    java_home: str
    spark_home: str

    @classmethod
    def from_env(cls, env: SparkEnv) -> 'MasterConfig':
        """Create configuration from environment variables."""
        # Determine master host based on environment
        if Path('/var/run/secrets/kubernetes.io/serviceaccount/token').exists():
            logger.info("Running in Kubernetes environment")
            master_host = env.SPARK_MASTER_HOST or socket.getfqdn()
        else:
            logger.info("Running in local environment")
            master_host = env.SPARK_MASTER_HOST or '0.0.0.0'

        return cls(
            master_host=master_host,
            master_port=env.SPARK_MASTER_PORT,
            master_webui_port=env.SPARK_MASTER_WEBUI_PORT,
            master_rest_port=env.SPARK_MASTER_REST_PORT,
            local_dirs=env.SPARK_LOCAL_DIRS,
            java_home=env.JAVA_HOME,
            spark_home=env.SPARK_HOME
        )

    def setup_directories(self) -> None:
        """Create and set permissions for required directories."""
        try:
            local_dir = Path(self.local_dirs)
            local_dir.mkdir(parents=True, exist_ok=True)
            # Change ownership to spark user (requires root)
            if os.geteuid() == 0:
                import pwd
                spark_uid = pwd.getpwnam('spark').pw_uid
                spark_gid = pwd.getpwnam('spark').pw_gid
                os.chown(local_dir, spark_uid, spark_gid)
        except Exception as e:
            logger.error(f"Failed to setup directories: {e}")
            raise

    def get_java_command(self) -> list[str]:
        """Build the Java command for starting the master."""
        java_opts = [
            f"{self.java_home}/bin/java",
            "-cp", f"{self.spark_home}/conf/:{self.spark_home}/jars/*",
            "-Xmx1g",
            "-Dspark.master.bindAddress=0.0.0.0",
            "-Dspark.master.webui.bindAddress=0.0.0.0",
            f"-Dspark.local.dir={self.local_dirs}",
            "org.apache.spark.deploy.master.Master",
            "--host", self.master_host,
            "--port", str(self.master_port),
            "--webui-port", str(self.master_webui_port),
            "--rest-port", str(self.master_rest_port)
        ]
        return java_opts

    def log_configuration(self) -> None:
        """Log the current configuration."""
        logger.info("Starting Spark master with configuration:")
        for field in self.__dataclass_fields__:
            value = getattr(self, field)
            logger.info(f"{field}: {value}")

def start_master(env: SparkEnv) -> None:
    """Start Spark master node."""
    try:
        # Load configuration
        config = MasterConfig.from_env(env)
        config.log_configuration()
        
        # Setup directories
        config.setup_directories()

        # Start the master
        logger.info("Starting Spark master process...")
        java_cmd = config.get_java_command()
        logger.debug(f"Executing command: {' '.join(java_cmd)}")
        
        # Use exec to replace the current process
        os.execv(java_cmd[0], java_cmd)

    except Exception as e:
        logger.error(f"Failed to start master: {e}")
        sys.exit(1)

if __name__ == "__main__":
    env = load_spark_env()
    start_master(env) 