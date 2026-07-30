"""Tests for upload selflink rewriting."""

from lxml import etree

from migrator.upload import _rewrite_filename, _rewrite_selflink

_ENV_NS = "http://www.clarin.eu/cmd/1"


def _make_record(selflink):
    return f"""<?xml version='1.0' encoding='UTF-8'?>
<CMD xmlns="{_ENV_NS}" CMDVersion="1.2">
  <Header>
    <MdSelfLink>{selflink}</MdSelfLink>
  </Header>
</CMD>
""".encode()


def _selflink(xml_bytes):
    doc = etree.fromstring(xml_bytes)
    return doc.find(f".//{{{_ENV_NS}}}MdSelfLink").text.strip()


class TestRewriteFilename:
    def test_prefix_prepended_to_filename(self):
        assert (
            _rewrite_filename("lb-201405278.xml", "aj-test")
            == "aj-test-lb-201405278.xml"
        )

    def test_empty_prefix_leaves_filename_unchanged(self):
        assert _rewrite_filename("lb-201405278.xml", "") == "lb-201405278.xml"


class TestRewriteSelflink:
    def test_prefix_inserted_before_lb(self):
        """Prefix is inserted before the lb- segment."""
        out = _rewrite_selflink(_make_record("urn:nbn:fi:lb-201405278"), "aj-test")
        assert _selflink(out) == "urn:nbn:fi:aj-test-lb-201405278"

    def test_empty_prefix_leaves_selflink_unchanged(self):
        """Empty prefix leaves the selflink untouched."""
        out = _rewrite_selflink(_make_record("urn:nbn:fi:lb-201405278"), "")
        assert _selflink(out) == "urn:nbn:fi:lb-201405278"

    def test_prefix_inserted_after_urn_nbn_fi_when_no_lb_segment(self):
        """When no lb- segment exists the prefix is inserted after urn:nbn:fi:."""
        out = _rewrite_selflink(_make_record("urn:nbn:fi:something-else"), "pfx")
        assert _selflink(out) == "urn:nbn:fi:pfx-something-else"

    def test_error_when_no_urn_nbn_fi(self):
        """A selflink without urn:nbn:fi: raises ValueError."""
        import pytest

        with pytest.raises(ValueError, match="urn:nbn:fi:"):
            _rewrite_selflink(_make_record("hdl:12345/some-handle"), "pfx")

    def test_no_selflink_element_is_harmless(self):
        """Records with no MdSelfLink are returned without error."""
        xml = f"""<?xml version='1.0' encoding='UTF-8'?>
<CMD xmlns="{_ENV_NS}" CMDVersion="1.2"><Header/></CMD>""".encode()
        out = _rewrite_selflink(xml, "pfx")
        assert etree.fromstring(out).find(f".//{{{_ENV_NS}}}MdSelfLink") is None
