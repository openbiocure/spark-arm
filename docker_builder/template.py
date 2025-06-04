"""Template management for Docker builder."""

from pathlib import Path
from typing import List, Optional
from jinja2 import Environment, FileSystemLoader, select_autoescape, TemplateNotFound
from .config import BuilderConfig

class TemplateManager:
    """Manages template loading and rendering."""

    def __init__(self, config: BuilderConfig):
        """Initialize template manager with configuration."""
        self.config = config
        self.env = Environment(
            loader=FileSystemLoader(str(config.template_dir)),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=True,
            lstrip_blocks=True
        )

    def list_components(self) -> List[str]:
        """List available component templates."""
        return [p.stem for p in self.config.template_dir.glob("*.j2")]

    def get_template(self, component: str) -> str:
        """Get template content for a component.
        
        Args:
            component: Name of the component
            
        Returns:
            Template content as string
            
        Raises:
            ValueError: If template doesn't exist
        """
        template_path = f"{component}.j2"
        if not (self.config.template_dir / template_path).exists():
            raise ValueError(f"Template not found for component: {component}")
        
        try:
            template = self.env.get_template(template_path)
            return template.render(
                config=self.config.load_config(),
                env=self.config.env.to_env_dict()
            )
        except TemplateNotFound:
            raise ValueError(f"Template not found: {template_path}")
        except Exception as e:
            raise RuntimeError(f"Failed to render template: {str(e)}")

    def render_to_file(self, component: str, output_dir: str = '.') -> Path:
        """Render template to a file.
        
        Args:
            component: Name of the component
            output_dir: Directory to write output to
            
        Returns:
            Path to the rendered file
            
        Raises:
            ValueError: If template doesn't exist
            RuntimeError: If rendering or writing fails
        """
        try:
            output = self.get_template(component)
            output_path = Path(output_dir) / f"Dockerfile.{component}"
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(output_path, 'w') as f:
                f.write(output)
                
            return output_path
        except Exception as e:
            raise RuntimeError(f"Failed to write template output: {str(e)}") 