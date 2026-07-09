# CMDI Profile Migrator

A tool for converting metadata records in [Comedi](https://clarino.uib.no/comedi) from one profile to another.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements_dev.txt  # or requirements.txt for production requirements only
```

## Configuration

Copy the example config and fill in your values:

```bash
cp config/template.yml config/migrator.yml
$EDITOR config/migrator.yml
```

Any key in the config file becomes the default for the matching CLI option. Pass the file to the tool with `--config PATH`.

## Usage

All commands are subcommands of `python -m migrator`. Run `python -m migrator --help` for list of commands and their usage.

## Running tests

```bash
python -m pytest
```
