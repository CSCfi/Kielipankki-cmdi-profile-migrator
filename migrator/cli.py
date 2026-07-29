"""CLI entry point for the CMDI profile migrator."""

# Click command functions naturally receive one argument per CLI option,
# so the too-many-arguments limit does not make sense here.
# pylint: disable=too-many-arguments,too-many-positional-arguments

from pathlib import Path

import click
import yaml  # type: ignore[import-untyped]  # PyYAML ships no type stubs
from migrator.convert import convert_dir as _convert_dir
from migrator.harvest import harvest as _harvest
from migrator.validate import validate_dir as _validate_dir

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
_opt_upload_identifier_prefix = click.option(
    "--upload-identifier-prefix",
    required=True,
    help="Prefix used when constructing identifiers for uploaded records",
)
_opt_session_id = click.option(
    "--session-id",
    required=True,
    help=(
        "Session ID for authentication "
        "(see https://clarino.uib.no/comedi/documentation/comedi-documentation#batch_upload)"
    ),
)
_opt_group = click.option(
    "--upload-group",
    required=True,
    help="Group to which uploaded records will belong",
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
    required=True,
    type=click.Path(exists=True),
    help="Path to XSD schema (set via config file or --schema)",
)
@_opt_quiet
def validate(converted_dir, schema, quiet):
    """Validate converted records against the destination profile XSD."""
    valid, invalid = _validate_dir(converted_dir, schema, quiet)
    click.echo(f"Done. {valid} valid, {invalid} invalid.")
    if invalid:
        raise click.ClickException(f"{invalid} record(s) failed validation.")


@cli.command()
@click.option(
    "--converted-dir",
    required=True,
    type=click.Path(exists=True),
    help="Directory containing the converted records to upload",
)
@_opt_upload_url
@_opt_upload_identifier_prefix
@_opt_group
@_opt_session_id
@click.option(
    "--dry-run",
    is_flag=True,
    default=True,
    help="Print what would be uploaded without uploading",
)
@_opt_limit
def upload(
    converted_dir,
    upload_url,
    upload_identifier_prefix,
    upload_group,
    session_id,
    dry_run,
    limit,
):
    """Upload converted records to the repository."""
    raise NotImplementedError("upload is not yet implemented")


@cli.command()
@_opt_oai_url
@_opt_oai_set
@_opt_upload_url
@_opt_upload_identifier_prefix
@_opt_group
@_opt_session_id
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
def run(
    oai_url,
    oai_set,
    upload_url,
    upload_identifier_prefix,
    upload_group,
    session_id,
    raw_dir,
    converted_dir,
    dry_run,
    limit,
):
    """Run the full pipeline: harvest, convert, validate and upload"""
    raise NotImplementedError("run is not yet implemented")
