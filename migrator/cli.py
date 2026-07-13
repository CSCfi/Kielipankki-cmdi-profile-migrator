"""CLI entry point for the CMDI profile migrator."""

# Click command functions naturally receive one argument per CLI option,
# so the too-many-arguments limit does not make sense here.
# pylint: disable=too-many-arguments,too-many-positional-arguments

from pathlib import Path

import click
import yaml  # type: ignore[import-untyped]  # PyYAML ships no type stubs
from migrator.convert import convert_dir as _convert_dir
from migrator.harvest import harvest as _harvest

_opt_quiet = click.option(
    "--quiet", "-q", is_flag=True, default=False, help="Suppress progress output"
)
_opt_oai_url = click.option("--oai-url", required=True, help="OAI-PMH base URL")
_opt_oai_set = click.option(
    "--set", "oai_set", required=True, help="OAI-PMH set to harvest"
)
_opt_upload_url = click.option(
    "--upload-url", required=True, help="URL used when uploading the records"
)
_opt_limit = click.option(
    "--limit", default=None, type=int, help="Stop after N records"
)


class _ConfigGroup(click.Group):
    """Group that loads a YAML config file and feeds its values as option defaults."""

    def _load_config(self, config_path):
        if config_path is None:
            return {}
        try:
            with Path(config_path).open(encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
        except FileNotFoundError as exc:
            raise click.BadParameter(
                f"config file not found: {config_path}",
                param_hint="'--config'",
            ) from exc

    def invoke(self, ctx):
        cfg = self._load_config(ctx.params.get("config"))
        ctx.default_map = {cmd: cfg for cmd in self.commands}
        super().invoke(ctx)


@click.group(cls=_ConfigGroup)
@click.option(
    "--config",
    default=None,
    type=click.Path(),
    help="Path to the config file (see config/template.yml)",
)
def cli(config):  # pylint: disable=unused-argument
    """CMDI profile migrator: convert resourceInfo records to resourceInfo-corpus-v1."""


@cli.command()
@_opt_oai_url
@_opt_oai_set
@click.option("--metadata-prefix", default="cmdi", show_default=True)
@click.option(
    "--raw-dir",
    required=True,
    type=click.Path(),
    help="Directory to save harvested records",
)
@_opt_limit
@_opt_quiet
def harvest(oai_url, oai_set, metadata_prefix, raw_dir, limit, quiet):
    """Harvest CMDI records from an OAI-PMH endpoint."""
    count = _harvest(oai_url, oai_set, metadata_prefix, raw_dir, limit, quiet)
    click.echo(f"Done. Saved {count} records to {raw_dir}.")


@cli.command()
@click.option(
    "--raw-dir",
    required=True,
    type=click.Path(exists=True),
    help="Directory containing the harvested records to convert",
)
@click.option(
    "--converted-dir",
    required=True,
    type=click.Path(),
    help="Directory to write the converted records",
)
@_opt_limit
@_opt_quiet
def convert(raw_dir, converted_dir, limit, quiet):
    """Convert records from resourceInfo to resourceInfo-corpus-v1."""
    count = _convert_dir(raw_dir, converted_dir, limit, quiet)
    click.echo(f"Done. Converted {count} records to {converted_dir}.")


@cli.command()
@click.option(
    "--converted-dir",
    required=True,
    type=click.Path(exists=True),
    help="Directory containing the converted records to validate",
)
@click.option(
    "--schema",
    default=None,
    type=click.Path(),
    help="Path to XSD schema",
)
def validate(converted_dir, schema):
    """Validate records against the new-profile XSD schema."""
    raise NotImplementedError("validate is not yet implemented")


@cli.command()
@click.option(
    "--converted-dir",
    required=True,
    type=click.Path(exists=True),
    help="Directory containing the converted records to upload",
)
@_opt_upload_url
@click.option(
    "--dry-run",
    is_flag=True,
    default=True,
    help="Print what would be uploaded without uploading",
)
@_opt_limit
def upload(converted_dir, upload_url, dry_run, limit):
    """Upload converted records to the repository."""
    raise NotImplementedError("upload is not yet implemented")


@cli.command()
@_opt_oai_url
@_opt_oai_set
@_opt_upload_url
@click.option(
    "--raw-dir",
    required=True,
    type=click.Path(),
    help="Directory to save harvested records",
)
@click.option(
    "--converted-dir",
    required=True,
    type=click.Path(),
    help="Directory to write converted records",
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Harvest and convert but do not upload",
)
@_opt_limit
def run(oai_url, oai_set, upload_url, raw_dir, converted_dir, dry_run, limit):
    """Run the full pipeline: harvest, convert, validate and upload"""
    raise NotImplementedError("run is not yet implemented")
