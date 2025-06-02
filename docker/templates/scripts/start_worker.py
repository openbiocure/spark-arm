#!/usr/bin/env python3
import os
import sys
import logging
import socket
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any
from dataclasses import dataclass
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

@dataclass
class WorkerConfig:
    """Configuration for Spark worker."""
    master_url: str
    worker_host: str
    worker_cores: int
    worker_memory: str
    worker_webui_port: int
    worker_port: int
    local_dirs: str
    worker_dir: str
    java_home: str
    spark_home: str

    @classmethod
    def from_env(cls) -> 'WorkerConfig':
        """Create configuration from environment variables."""
        # Required environment variables
        master_url = os.environ.get('SPARK_MASTER_URL')
        if not master_url:
            raise ValueError("SPARK_MASTER_URL environment variable is required")

        # Determine worker host based on environment
        if Path('/var/run/secrets/kubernetes.io/serviceaccount/token').exists():
            logger.info("Running in Kubernetes environment")
            worker_host = os.environ.get('SPARK_WORKER_HOST', socket.getfqdn())
        else:
            logger.info("Running in local environment")
            worker_host = os.environ.get('SPARK_WORKER_HOST', '0.0.0.0')

        return cls(
            master_url=master_url,
            worker_host=worker_host,
            worker_cores=int(os.environ.get('SPARK_WORKER_CORES', '1')),
            worker_memory=os.environ.get('SPARK_WORKER_MEMORY', '1g'),
            worker_webui_port=int(os.environ.get('SPARK_WORKER_WEBUI_PORT', '8081')),
            worker_port=int(os.environ.get('SPARK_WORKER_PORT', '0')),
            local_dirs=os.environ.get('SPARK_LOCAL_DIRS', '/opt/spark/tmp'),
            worker_dir=os.environ.get('SPARK_WORKER_DIR', '/opt/spark/work'),
            java_home=os.environ.get('JAVA_HOME', '/opt/java/openjdk'),
            spark_home=os.environ.get('SPARK_HOME', '/opt/spark')
        )

    def setup_directories(self) -> None:
        """Create and set permissions for required directories."""
        try:
            worker_dir = Path(self.worker_dir)
            worker_dir.mkdir(parents=True, exist_ok=True)
            # Change ownership to spark user (requires root)
            if os.geteuid() == 0:
                import pwd
                spark_uid = pwd.getpwnam('spark').pw_uid
                spark_gid = pwd.getpwnam('spark').pw_gid
                os.chown(worker_dir, spark_uid, spark_gid)
        except Exception as e:
            logger.error(f"Failed to setup directories: {e}")
            raise

    def get_java_command(self) -> list[str]:
        """Build the Java command for starting the worker."""
        java_opts = [
            f"{self.java_home}/bin/java",
            "-cp", f"{self.spark_home}/conf/:{self.spark_home}/jars/*",
            "-Xmx1g",
            "-Dspark.worker.bindAddress=0.0.0.0",
            "-Dspark.worker.webui.bindAddress=0.0.0.0",
            f"-Dspark.local.dir={self.local_dirs}",
            f"-Dspark.worker.dir={self.worker_dir}",
            "org.apache.spark.deploy.worker.Worker",
            "--host", self.worker_host,
            "--port", str(self.worker_port),
            "--webui-port", str(self.worker_webui_port),
            "--cores", str(self.worker_cores),
            "--memory", self.worker_memory,
            self.master_url
        ]
        return java_opts

    def log_configuration(self) -> None:
        """Log the current configuration."""
        logger.info("Starting Spark worker with configuration:")
        for field in self.__dataclass_fields__:
            value = getattr(self, field)
            logger.info(f"{field}: {value}")

def main() -> None:
    """Main entry point for the worker script."""
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser(description='Start Spark worker')
        parser.add_argument('--debug', action='store_true', help='Enable debug logging')
        args = parser.parse_args()

        if args.debug:
            logger.setLevel(logging.DEBUG)

        # Load configuration
        config = WorkerConfig.from_env()
        config.log_configuration()
        
        # Setup directories
        config.setup_directories()

        # Start the worker
        logger.info("Starting Spark worker process...")
        java_cmd = config.get_java_command()
        logger.debug(f"Executing command: {' '.join(java_cmd)}")
        
        # Use exec to replace the current process
        os.execv(java_cmd[0], java_cmd)

    except Exception as e:
        logger.error(f"Failed to start worker: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main() 