#!/usr/bin/env python3
"""Generate spark-defaults.conf for Spark configuration."""

import os
import logging
from pathlib import Path
from typing import Optional
from jinja2 import Environment, FileSystemLoader

try:
    from docker.utils.version_config import VersionConfig
except ImportError:
    raise ImportError("Could not import VersionConfig. Make sure docker/utils is in PYTHONPATH")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def create_spark_defaults(config: Optional[VersionConfig] = None) -> None:
    """Create spark-defaults.conf using version configuration.
    
    Args:
        config: VersionConfig instance. If None, will load from default path.
    """
    config = config or VersionConfig.load()
    spark_config = config.get_component_config('spark')
    conf_dir = Path(spark_config['home']) / 'conf'
    conf_file = conf_dir / 'spark-defaults.conf'
    
    logger.info(f"Creating spark-defaults.conf in {conf_dir}")
    
    try:
        # Initialize Jinja2 environment
        template_dir = Path(__file__).parent.parent.parent / 'templates'
        jinja_env = Environment(
            loader=FileSystemLoader(str(template_dir)),
            trim_blocks=True,
            lstrip_blocks=True
        )
        
        # Load and render template
        template = jinja_env.get_template('spark-defaults.conf.j2')
        context = {
            'versions': config.versions,
            'components': config.components.model_dump(),
            'env': os.environ
        }
        config_content = template.render(**context)
        
        # Write configuration
        conf_dir.mkdir(parents=True, exist_ok=True)
        with open(conf_file, 'w') as f:
            f.write(config_content)
        logger.info("Created spark-defaults.conf successfully")
    except Exception as e:
        logger.error(f"Failed to create spark-defaults.conf: {e}")
        raise

if __name__ == '__main__':
    create_spark_defaults() 