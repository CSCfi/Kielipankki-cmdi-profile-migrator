"""Tests for CMDI record validation."""

# pylint: disable=c-extension-no-member

import pytest
from lxml import etree  # type: ignore[import-untyped]  # lxml ships no type stubs

from migrator.validate import validate_record

# Minimal XSD that accepts a <record> with a required <title> child.
_SCHEMA_XML = b"""<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="record">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="title" type="xs:string"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>
"""

_VALID_RECORD = b"<record><title>Test</title></record>"
_MISSING_TITLE = b"<record/>"
_WRONG_ROOT = b"<other><title>Test</title></other>"


@pytest.fixture
def schema():
    return etree.XMLSchema(etree.fromstring(_SCHEMA_XML))


class TestValidateRecord:
    def test_valid_record_returns_no_errors(self, schema):
        assert validate_record(_VALID_RECORD, schema) == []

    def test_missing_required_element_returns_errors(self, schema):
        errors = validate_record(_MISSING_TITLE, schema)
        assert len(errors) > 0

    def test_wrong_root_returns_errors(self, schema):
        errors = validate_record(_WRONG_ROOT, schema)
        assert len(errors) > 0

    def test_error_messages_are_strings(self, schema):
        errors = validate_record(_MISSING_TITLE, schema)
        assert all(isinstance(e, str) for e in errors)
