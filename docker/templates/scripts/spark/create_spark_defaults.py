#!/usr/bin/env python3
"""Generate spark-defaults.conf for Spark configuration."""

import os
import logging
from pathlib import Path
from typing import Optional
from jinja2 import Environment, FileSystemLoader

# Add the scripts directory to Python path
scripts_dir = Path(__file__).parent
import sys
sys.path.append(str(scripts_dir))

try:
    from env import SparkEnv
except ImportError:
    raise ImportError("Could not import SparkEnv from env.py")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def create_spark_defaults(env: Optional[SparkEnv] = None) -> None:
    """Create spark-defaults.conf using Spark environment configuration.
    
    Args:
        env: SparkEnv instance. If None, will load from environment.
    """
    env = env or SparkEnv()
    conf_dir = Path(env.spark_conf_dir)
    conf_file = conf_dir / 'spark-defaults.conf'
    
    logger.info(f"Creating spark-defaults.conf in {conf_dir}")
    
    try:
        # Initialize Jinja2 environment
        template_dir = Path(__file__).parent.parent / 'conf'
        jinja_env = Environment(
            loader=FileSystemLoader(str(template_dir)),
            trim_blocks=True,
            lstrip_blocks=True
        )
        
        # Load and render template
        template = jinja_env.get_template('spark-defaults.conf.j2')
        config = template.render(env=env)
        
        # Write configuration
        conf_dir.mkdir(parents=True, exist_ok=True)
        with open(conf_file, 'w') as f:
            f.write(config)
        logger.info("Created spark-defaults.conf successfully")
    except Exception as e:
        logger.error(f"Failed to create spark-defaults.conf: {e}")
        raise

if __name__ == "__main__":
    create_spark_defaults() 