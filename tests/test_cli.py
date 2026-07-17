"""Tests for CLI config file loading."""

# pytest fixtures are injected by name, which pylint sees as shadowing the
# module-level fixture function.
# pylint: disable=redefined-outer-name
import pytest
from click.testing import CliRunner

from migrator.cli import cli


@pytest.fixture
def runner():
    """Provide a Click test runner."""
    return CliRunner()


@pytest.fixture
def config_file(tmp_path):
    """Write a minimal config file and return its path."""
    f = tmp_path / "migrator.yml"
    f.write_text(
        "oai_url: https://oai.example.org/oai\n"
        "oai_set: my-corpus\n"
        "upload_url: https://api.example.org\n"
        "raw_dir: .\n"
        f"converted_dir: {tmp_path}/converted\n",
        encoding="utf-8",
    )
    return str(f)


class TestConfig:
    """Tests for YAML config file loading and option defaulting."""

    def test_missing_config_file_gives_clean_error(self, runner):
        """A non-existent config path should produce a user-friendly error."""
        result = runner.invoke(cli, ["--config", "/no/such/file.yml", "harvest"])
        assert result.exit_code != 0
        assert "config file not found" in result.output

    def test_config_values_satisfy_required_options(self, runner, config_file):
        """Config file values should be used to satisfy required options."""
        result = runner.invoke(
            cli,
            ["--config", config_file, "convert"],
        )
        assert "Missing option" not in result.output

    def test_config_value_can_be_overridden_by_flag(self, runner, config_file):
        """An explicit CLI flag should take precedence over the config file value."""
        result = runner.invoke(
            cli,
            [
                "--config",
                config_file,
                "harvest",
                "--oai-url",
                "https://other.org/oai",
                "--set",
                "other-corpus",
                "--raw-dir",
                ".",
            ],
        )
        assert "Missing option" not in result.output
