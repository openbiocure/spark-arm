"""Command-line interface for Docker builder tools."""

import sys
from pathlib import Path
import click
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.panel import Panel
from .renderer import DockerfileRenderer

# Initialize console
console = Console()

def handle_error(func):
    """Decorator to handle errors in CLI commands."""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            console.print(Panel(
                f"[red]Error:[/] {str(e)}",
                title="Error",
                border_style="red"
            ))
            sys.exit(1)
    return wrapper

@click.group()
def cli():
    """Docker builder tools for Spark components."""
    pass

@cli.command(name='list')
@handle_error
def list_command():
    """List available component templates."""
    renderer = DockerfileRenderer()
    components = renderer.list_components()
    
    if not components:
        console.print("[yellow]No component templates found.[/]")
        return
    
    console.print("\n[bold]Available components:[/]")
    for component in components:
        console.print(f"  • {component}")

@cli.command(name='render')
@click.argument('component')
@click.option('--config', '-c', 
              help='Path to configuration file',
              type=click.Path(exists=True, dir_okay=False, file_okay=True))
@click.option('--output', '-o', 
              help='Output directory for generated files',
              type=click.Path(file_okay=False))
@handle_error
def render_command(component: str, config: str, output: str):
    """Render a Dockerfile for the specified component."""
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:
        task = progress.add_task(f"Rendering {component}...", total=None)
        
        # Validate paths
        config_path = Path(config) if config else Path('docker/configs/versions.yaml')
        output_path = Path(output) if output else Path('docker/output')
        
        if not config_path.exists():
            raise ValueError(f"Config file not found: {config_path}")
        
        if not output_path.exists():
            output_path.mkdir(parents=True)
        
        # Render component
        renderer = DockerfileRenderer(config_path=str(config_path))
        output_file = renderer.render(component, output_dir=str(output_path))
        
        progress.update(task, completed=True)
    
    # Show success message
    console.print(Panel(
        f"[green]✓[/] Successfully rendered [bold blue]{component}[/]\n"
        f"Output: [blue]{output_file}[/]",
        title="Render Complete",
        border_style="green"
    ))

if __name__ == '__main__':
    cli() 