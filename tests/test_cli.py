"""Tests for CLI config file loading."""
# pytest fixtures are injected by name, which pylint sees as shadowing the
# module-level fixture function. Test methods and classes are self-documenting
# through their names, so docstrings are omitted.
# pylint: disable=redefined-outer-name,missing-function-docstring,missing-class-docstring
import pytest
from click.testing import CliRunner

from migrator.cli import cli


@pytest.fixture
def runner():
    return CliRunner()


@pytest.fixture
def config_file(tmp_path):
    f = tmp_path / "migrator.yml"
    f.write_text(
        "oai_url: https://oai.example.org/oai\n"
        "oai_set: my-corpus\n"
        "upload_url: https://api.example.org\n"
        "input_dir: .\n"
        "output_dir: ./out\n",
        encoding="utf-8",
    )
    return str(f)


class TestConfig:
    def test_missing_config_file_gives_clean_error(self, runner):
        result = runner.invoke(cli, ["--config", "/no/such/file.yml", "harvest"])
        assert result.exit_code != 0
        assert "config file not found" in result.output

    def test_config_values_satisfy_required_options(self, runner, config_file, tmp_path):
        result = runner.invoke(
            cli,
            ["--config", config_file, "convert", "--output-dir", str(tmp_path)],
        )
        assert "Missing option" not in result.output

    def test_config_value_can_be_overridden_by_flag(self, runner, config_file):
        result = runner.invoke(
            cli,
            ["--config", config_file, "harvest", "--oai-url", "https://other.org/oai",
             "--set", "other-corpus", "--output-dir", "."],
        )
        assert "Missing option" not in result.output
