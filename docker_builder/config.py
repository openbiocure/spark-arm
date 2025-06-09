"""Configuration management for Docker builder."""

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Any, Optional, Union
import yaml
from .env import SparkEnv

@dataclass
class BuilderConfig:
    """Configuration for Docker builder."""
    base_dir: Path
    template_dir: Path
    config_path: Path
    env: SparkEnv

    @classmethod
    def from_path(cls, config_path: Union[str, Path] = 'config.yaml') -> 'BuilderConfig':
        """Create a BuilderConfig instance from a config file path."""
        base_dir = Path(__file__).parent.parent.parent
        template_dir = base_dir / 'docker' / 'templates'
        config_path = Path(config_path)
        
        # Load environment configuration
        env = SparkEnv.load_spark_env()
        
        return cls(
            base_dir=base_dir,
            template_dir=template_dir,
            config_path=config_path,
            env=env
        )

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        if not self.config_path.exists():
            return {}
        
        try:
            with open(self.config_path) as f:
                config = yaml.safe_load(f)
                return config or {}
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML configuration: {str(e)}")
        except Exception as e:
            raise RuntimeError(f"Failed to load configuration: {str(e)}")

    def validate(self) -> None:
        """Validate the configuration."""
        if not self.template_dir.exists():
            raise ValueError(f"Template directory not found: {self.template_dir}")
        
        if not self.template_dir.is_dir():
            raise ValueError(f"Template path is not a directory: {self.template_dir}")
        
        if self.config_path.exists() and not self.config_path.is_file():
            raise ValueError(f"Config path is not a file: {self.config_path}") 