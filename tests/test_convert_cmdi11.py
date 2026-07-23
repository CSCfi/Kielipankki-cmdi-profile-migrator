"""Tests for CMDI 1.1 resourceInfo -> CMDI 1.2 resourceInfo-corpus-v1 conversion."""

# lxml is a C extension - pylint cannot introspect its members at analysis time.
# pylint: disable=c-extension-no-member

from lxml import etree  # type: ignore[import-untyped]  # lxml ships no type stubs

from migrator.convert import convert

# Input record namespace (CMDI 1.1 - used only in fixture construction)
CMD_NS = "http://www.clarin.eu/cmd/"
OLD_PROFILE = "clarin.eu:cr1:p_1361876010571"
NEW_PROFILE = "clarin.eu:cr1:p_1778593302234"

# Output namespaces (CMDI 1.2)
ENV_NS = "http://www.clarin.eu/cmd/1"
NEW_PROFILE_NS = f"http://www.clarin.eu/cmd/1/profiles/{NEW_PROFILE}"

_REGISTRY = "http://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/profiles"
_OLD_SCHEMA_LOC = f"{_REGISTRY}/{OLD_PROFILE}/xsd"

# Minimal CMDI 1.1 record covering every conversion rule.
_MINIMAL_RECORD = f"""<?xml version='1.0' encoding='UTF-8'?>
<CMD xmlns="{CMD_NS}"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     CMDVersion="1.1"
     xsi:schemaLocation="{CMD_NS} {_OLD_SCHEMA_LOC}">
  <Header>
    <MdCreator>Test</MdCreator>
    <MdCreationDate>2026-01-01</MdCreationDate>
    <MdSelfLink>urn:nbn:fi:lb-1</MdSelfLink>
    <MdProfile>{OLD_PROFILE}</MdProfile>
  </Header>
  <Resources><ResourceProxyList/></Resources>
  <Components>
    <resourceInfo>
      <identificationInfo ComponentId="clarin.eu:cr1:c_1349361150743">
        <resourceName xml:lang="en">Test Corpus</resourceName>
        <resourceShortName xml:lang="en">test-corpus</resourceShortName>
        <description xml:lang="en">A test corpus.</description>
        <metaShareId>n/a</metaShareId>
        <identifier>http://urn.fi/urn:nbn:fi:lb-1</identifier>
      </identificationInfo>
      <distributionInfo ComponentId="clarin.eu:cr1:c_1352813745459">
        <availability>available-unrestrictedUse</availability>
        <licenceInfo ComponentId="clarin.eu:cr1:c_1352813745464">
          <licence>CC-BY</licence>
          <restrictionsOfUse>academic-nonCommercialUse</restrictionsOfUse>
          <distributionRightsHolderOrganization ComponentId="clarin.eu:cr1:c_1361876010640">
            <role>distributionRightsHolder</role>
            <organizationInfo ComponentId="clarin.eu:cr1:c_1352813745461">
              <organizationName xml:lang="en">University of Helsinki</organizationName>
              <communicationInfo ComponentId="clarin.eu:cr1:c_1352813745460">
                <email>test@helsinki.fi</email>
              </communicationInfo>
            </organizationInfo>
          </distributionRightsHolderOrganization>
        </licenceInfo>
      </distributionInfo>
    </resourceInfo>
  </Components>
</CMD>
""".encode()


def _convert_and_parse(record=None):
    """Convert a record and return its parsed element tree."""
    return etree.fromstring(convert(record or _MINIMAL_RECORD))


def _record_with_licence(licence_value, availability="underNegotiation"):
    """Build a minimal CMDI 1.1 record with a given licence and availability value."""
    return f"""<?xml version='1.0' encoding='UTF-8'?>
<CMD xmlns="{CMD_NS}" CMDVersion="1.1">
  <Header><MdProfile>{OLD_PROFILE}</MdProfile></Header>
  <Resources><ResourceProxyList/></Resources>
  <Components>
    <resourceInfo>
      <identificationInfo ComponentId="clarin.eu:cr1:c_1349361150743">
        <resourceName xml:lang="en">Test</resourceName>
        <description xml:lang="en">Test.</description>
      </identificationInfo>
      <distributionInfo ComponentId="clarin.eu:cr1:c_1352813745459">
        <availability>{availability}</availability>
        <licenceInfo ComponentId="clarin.eu:cr1:c_1352813745464">
          <licence>{licence_value}</licence>
        </licenceInfo>
      </distributionInfo>
    </resourceInfo>
  </Components>
</CMD>
""".encode()


def _ns(tag):
    """Return a Clark-notation tag in the output profile namespace."""
    return f"{{{NEW_PROFILE_NS}}}{tag}"


def _env(tag):
    """Return a Clark-notation tag in the output CMDI 1.2 envelope namespace."""
    return f"{{{ENV_NS}}}{tag}"


class TestProfileUpdate:
    """Tests that the profile ID and schemaLocation are updated."""

    def test_mdprofile_updated(self):
        """MdProfile element should contain the new profile ID."""
        root = _convert_and_parse()
        profile = root.find(f".//{_env('MdProfile')}")
        assert profile.text == NEW_PROFILE

    def test_schemalocation_updated(self):
        """xsi:schemaLocation attribute should reference the new profile."""
        root = _convert_and_parse()
        xsi_ns = "http://www.w3.org/2001/XMLSchema-instance"
        loc = root.get(f"{{{xsi_ns}}}schemaLocation")
        assert NEW_PROFILE in loc
        assert OLD_PROFILE not in loc

    def test_output_is_cmdi12(self):
        """Root CMD element should be in the CMDI 1.2 envelope namespace."""
        root = _convert_and_parse()
        assert root.tag == _env("CMD")

    def test_cmdversion_is_12(self):
        """CMDVersion attribute should be updated to 1.2."""
        root = _convert_and_parse()
        assert root.get("CMDVersion") == "1.2"


class TestRootComponentRename:
    """Tests that the root component is renamed."""

    def test_root_component_renamed(self):
        """<resourceInfo> should become <resourceInfo-corpus-v1>."""
        root = _convert_and_parse()
        components = root.find(_env("Components"))
        assert components[0].tag == _ns("resourceInfo-corpus-v1")

    def test_old_root_component_absent(self):
        """<resourceInfo> should not appear in the output."""
        root = _convert_and_parse()
        assert root.find(f".//{_ns('resourceInfo')}") is None


class TestIdentificationInfo:
    """Tests for identificationInfo restructuring."""

    def test_resourcename_kept(self):
        """resourceName is preserved."""
        root = _convert_and_parse()
        el = root.find(f".//{_ns('resourceName')}")
        assert el is not None and el.text == "Test Corpus"

    def test_resourceshortname_kept(self):
        """resourceShortName is preserved."""
        root = _convert_and_parse()
        el = root.find(f".//{_ns('resourceShortName')}")
        assert el is not None and el.text == "test-corpus"

    def test_description_kept(self):
        """description is preserved."""
        root = _convert_and_parse()
        el = root.find(f".//{_ns('description')}")
        assert el is not None

    def test_metashareid_dropped(self):
        """metaShareId is removed."""
        root = _convert_and_parse()
        assert root.find(f".//{_ns('metaShareId')}") is None

    def test_identifier_dropped(self):
        """identifier is removed."""
        root = _convert_and_parse()
        assert root.find(f".//{_ns('identifier')}") is None

    def test_component_id_dropped(self):
        """ComponentId attributes are absent from CMDI 1.2 output."""
        root = _convert_and_parse()
        info = root.find(f".//{_ns('identificationInfo')}")
        assert info.get("ComponentId") is None


class TestDistributionInfo:
    """Tests for distributionInfo restructuring."""

    def test_access_info_added(self):
        """An empty accessInfo element is added."""
        root = _convert_and_parse()
        assert root.find(f".//{_ns('accessInfo')}") is not None

    def test_licence_info_renamed(self):
        """licenceInfo is replaced by licenseInfo."""
        root = _convert_and_parse()
        assert root.find(f".//{_ns('licenceInfo')}") is None
        assert root.find(f".//{_ns('licenseInfo')}") is not None

    def test_restrictions_of_use_dropped(self):
        """restrictionsOfUse is removed."""
        root = _convert_and_parse()
        assert root.find(f".//{_ns('restrictionsOfUse')}") is None

    def test_rights_holder_organisation_kept(self):
        """distributionRightsHolderOrganization is preserved inside licenseInfo."""
        root = _convert_and_parse()
        license_info = root.find(f".//{_ns('licenseInfo')}")
        assert (
            license_info.find(_ns("distributionRightsHolderOrganization")) is not None
        )


_RECORD_WITH_VERSION_INFO = f"""<?xml version='1.0' encoding='UTF-8'?>
<CMD xmlns="{CMD_NS}" CMDVersion="1.1">
  <Header><MdProfile>{OLD_PROFILE}</MdProfile></Header>
  <Resources><ResourceProxyList/></Resources>
  <Components>
    <resourceInfo>
      <identificationInfo ComponentId="clarin.eu:cr1:c_1349361150743">
        <resourceName xml:lang="en">Test</resourceName>
        <description xml:lang="en">Test.</description>
      </identificationInfo>
      <distributionInfo ComponentId="clarin.eu:cr1:c_1352813745459">
        <availability>available-unrestrictedUse</availability>
        <licenceInfo ComponentId="clarin.eu:cr1:c_1352813745464">
          <licence>CC-BY</licence>
        </licenceInfo>
      </distributionInfo>
      <versionInfo ComponentId="clarin.eu:cr1:c_1353678848783">
        <version>2.1</version>
        <revision>Added new annotations.</revision>
        <lastDateUpdated>2024-03-15</lastDateUpdated>
        <updateFrequency>irregular</updateFrequency>
      </versionInfo>
    </resourceInfo>
  </Components>
</CMD>
""".encode()


class TestVersionInfo:
    """Tests for versionInfo pass-through conversion."""

    def test_version_info_present(self):
        root = _convert_and_parse(_RECORD_WITH_VERSION_INFO)
        assert root.find(f".//{_ns('versionInfo')}") is not None

    def test_version_value(self):
        root = _convert_and_parse(_RECORD_WITH_VERSION_INFO)
        assert root.find(f".//{_ns('versionInfo')}/{_ns('version')}").text == "2.1"

    def test_revision(self):
        root = _convert_and_parse(_RECORD_WITH_VERSION_INFO)
        el = root.find(f".//{_ns('versionInfo')}/{_ns('revision')}")
        assert el.text == "Added new annotations."

    def test_last_date_updated(self):
        root = _convert_and_parse(_RECORD_WITH_VERSION_INFO)
        el = root.find(f".//{_ns('versionInfo')}/{_ns('lastDateUpdated')}")
        assert el.text == "2024-03-15"

    def test_update_frequency(self):
        root = _convert_and_parse(_RECORD_WITH_VERSION_INFO)
        el = root.find(f".//{_ns('versionInfo')}/{_ns('updateFrequency')}")
        assert el.text == "irregular"

    def test_version_info_absent_when_not_in_source(self):
        root = _convert_and_parse()
        assert root.find(f".//{_ns('versionInfo')}") is None


class TestAvailabilityMapping:
    """Tests for availability value mapping."""

    def test_available_unrestricted_maps_to_available(self):
        """available-unrestrictedUse -> Available."""
        root = _convert_and_parse(
            _record_with_licence("CC-BY", "available-unrestrictedUse")
        )
        assert root.find(f".//{_ns('availability')}").text == "Available"

    def test_available_restricted_maps_to_available(self):
        """available-restrictedUse -> Available."""
        root = _convert_and_parse(
            _record_with_licence("CC-BY", "available-restrictedUse")
        )
        assert root.find(f".//{_ns('availability')}").text == "Available"

    def test_not_available_maps_to_archived(self):
        """notAvailableThroughMetaShare -> Archived."""
        root = _convert_and_parse(
            _record_with_licence("CC-BY", "notAvailableThroughMetaShare")
        )
        assert root.find(f".//{_ns('availability')}").text == "Archived"

    def test_under_negotiation_maps_to_preliminary(self):
        """underNegotiation -> Preliminary."""
        root = _convert_and_parse(_record_with_licence("CC-BY", "underNegotiation"))
        assert root.find(f".//{_ns('availability')}").text == "Preliminary"


class TestLicenceMapping:
    """Tests for licence -> licenseType value mapping."""

    def _license_type(self, licence_value):
        root = _convert_and_parse(_record_with_licence(licence_value))
        return root.find(f".//{_ns('licenseType')}").text

    def test_cc_by(self):
        """CC-BY -> CC BY."""
        assert self._license_type("CC-BY") == "CC BY"

    def test_cc_by_nc(self):
        """CC-BY-NC -> CC BY-NC."""
        assert self._license_type("CC-BY-NC") == "CC BY-NC"

    def test_cc_zero(self):
        """CC-ZERO -> CC0."""
        assert self._license_type("CC-ZERO") == "CC0"

    def test_clarin_pub(self):
        """CLARIN_PUB is ambiguous and gets a TODO marker."""
        assert (
            self._license_type("CLARIN_PUB")
            == "TODO: ambiguous value CLARIN_PUB in original"
        )

    def test_clarin_aca(self):
        """CLARIN_ACA is ambiguous and gets a TODO marker."""
        assert (
            self._license_type("CLARIN_ACA")
            == "TODO: ambiguous value CLARIN_ACA in original"
        )

    def test_clarin_res(self):
        """CLARIN_RES is ambiguous and gets a TODO marker."""
        assert (
            self._license_type("CLARIN_RES")
            == "TODO: ambiguous value CLARIN_RES in original"
        )

    def test_unknown_gets_prefix(self):
        """Unmapped values get the :: prefix so no data is lost."""
        assert self._license_type("underNegotiation") == ":: underNegotiation"

    def test_cc_by_gets_license_link(self):
        """Known CC licences produce a licenseLink with a canonical URL."""
        root = _convert_and_parse(_record_with_licence("CC-BY"))
        url = root.find(f".//{_ns('licenseLink')}/{_ns('link')}/{_ns('url')}")
        assert url is not None
        assert "creativecommons.org" in url.text

    def test_unknown_licence_has_no_license_link(self):
        """Unmapped licences produce no licenseLink"""
        root = _convert_and_parse(_record_with_licence("underNegotiation"))
        assert root.find(f".//{_ns('licenseLink')}") is None


_RECORD_WITH_IPR_HOLDERS = f"""<?xml version='1.0' encoding='UTF-8'?>
<CMD xmlns="{CMD_NS}" CMDVersion="1.1">
  <Header><MdProfile>{OLD_PROFILE}</MdProfile></Header>
  <Resources><ResourceProxyList/></Resources>
  <Components>
    <resourceInfo>
      <identificationInfo ComponentId="clarin.eu:cr1:c_1349361150743">
        <resourceName xml:lang="en">Test</resourceName>
        <description xml:lang="en">Test.</description>
      </identificationInfo>
      <distributionInfo ComponentId="clarin.eu:cr1:c_1352813745459">
        <availability>available-unrestrictedUse</availability>
        <licenceInfo ComponentId="clarin.eu:cr1:c_1352813745464">
          <licence>CC-BY</licence>
        </licenceInfo>
        <iprHolder ComponentId="clarin.eu:cr1:c_1361876010641">
          <role>iprHolder</role>
          <personInfo ComponentId="clarin.eu:cr1:c_1349361150746">
            <surname xml:lang="en">Smith</surname>
            <communicationInfo ComponentId="clarin.eu:cr1:c_1352813745460">
              <email>smith@example.com</email>
            </communicationInfo>
          </personInfo>
        </iprHolder>
        <iprHolderOrganization ComponentId="clarin.eu:cr1:c_1361876010642">
          <role>iprHolder</role>
          <organizationInfo ComponentId="clarin.eu:cr1:c_1352813745461">
            <organizationName xml:lang="en">Example Org</organizationName>
            <communicationInfo ComponentId="clarin.eu:cr1:c_1352813745460">
              <email>org@example.com</email>
            </communicationInfo>
          </organizationInfo>
        </iprHolderOrganization>
      </distributionInfo>
    </resourceInfo>
  </Components>
</CMD>
""".encode()


_RECORD_WITH_METADATA_CREATOR = f"""<?xml version='1.0' encoding='UTF-8'?>
<CMD xmlns="{CMD_NS}" CMDVersion="1.1">
  <Header>
    <MdSelfLink>urn:nbn:fi:lb-test</MdSelfLink>
    <MdProfile>{OLD_PROFILE}</MdProfile>
  </Header>
  <Resources><ResourceProxyList/></Resources>
  <Components>
    <resourceInfo>
      <identificationInfo ComponentId="clarin.eu:cr1:c_1349361150743">
        <resourceName xml:lang="en">Test</resourceName>
        <description xml:lang="en">Test.</description>
      </identificationInfo>
      <distributionInfo ComponentId="clarin.eu:cr1:c_1352813745459">
        <availability>available-unrestrictedUse</availability>
        <licenceInfo ComponentId="clarin.eu:cr1:c_1352813745464">
          <licence>CC-BY</licence>
        </licenceInfo>
      </distributionInfo>
      <metadataInfo ComponentId="clarin.eu:cr1:c_1349361150745">
        <metadataCreationDate>2024-01-01</metadataCreationDate>
        <metadataCreator ComponentId="clarin.eu:cr1:c_1353678848723">
          <role>metadataCreator</role>
          <personInfo ComponentId="clarin.eu:cr1:c_1349361150746">
            <surname xml:lang="en">Testaaja</surname>
            <givenName xml:lang="en">Tiina</givenName>
            <sex>unknown</sex>
            <communicationInfo ComponentId="clarin.eu:cr1:c_1352813745460">
              <email>tiina@example.com</email>
            </communicationInfo>
          </personInfo>
        </metadataCreator>
      </metadataInfo>
    </resourceInfo>
  </Components>
</CMD>
""".encode()


class TestMetadataCreatorConversion:
    """Tests that metadataCreator is migrated into the new profile structure."""

    def test_metadata_creator_present(self):
        root = _convert_and_parse(_RECORD_WITH_METADATA_CREATOR)
        assert root.find(f".//{_ns('metadataCreator')}") is not None

    def test_metadata_creator_surname(self):
        root = _convert_and_parse(_RECORD_WITH_METADATA_CREATOR)
        surname = root.find(
            f".//{_ns('metadataCreator')}/{_ns('personInfo')}/{_ns('surname')}"
        )
        assert surname is not None and surname.text == "Testaaja"

    def test_metadata_creator_given_name(self):
        root = _convert_and_parse(_RECORD_WITH_METADATA_CREATOR)
        given = root.find(
            f".//{_ns('metadataCreator')}/{_ns('personInfo')}/{_ns('givenName')}"
        )
        assert given is not None and given.text == "Tiina"

    def test_metadata_creator_email_lifted(self):
        """Email is lifted out of communicationInfo into personInfo directly."""
        root = _convert_and_parse(_RECORD_WITH_METADATA_CREATOR)
        email = root.find(
            f".//{_ns('metadataCreator')}/{_ns('personInfo')}/{_ns('email')}"
        )
        assert email is not None and email.text == "tiina@example.com"

    def test_metadata_creator_no_role(self):
        """New profile's metadataCreator has no role child."""
        root = _convert_and_parse(_RECORD_WITH_METADATA_CREATOR)
        creator = root.find(f".//{_ns('metadataCreator')}")
        assert creator.find(_ns("role")) is None

    def test_metadata_creator_no_communication_info(self):
        """communicationInfo wrapper is not present in new metadataCreator/personInfo."""
        root = _convert_and_parse(_RECORD_WITH_METADATA_CREATOR)
        assert (
            root.find(f".//{_ns('metadataCreator')}//{_ns('communicationInfo')}")
            is None
        )

    def test_multiple_creators_get_todo(self):
        """Multiple metadataCreators produce a single TODO marker instead of silently dropping."""
        two_creators = _RECORD_WITH_METADATA_CREATOR.replace(
            b"</metadataCreator>",
            b"""</metadataCreator>
        <metadataCreator ComponentId="clarin.eu:cr1:c_1353678848723">
          <role>metadataCreator</role>
          <personInfo ComponentId="clarin.eu:cr1:c_1349361150746">
            <surname xml:lang="en">Second</surname>
            <givenName xml:lang="en">Person</givenName>
          </personInfo>
        </metadataCreator>""",
            1,
        )
        root = _convert_and_parse(two_creators)
        assert len(root.findall(f".//{_ns('metadataCreator')}")) == 1
        surname = root.find(
            f".//{_ns('metadataCreator')}/{_ns('personInfo')}/{_ns('surname')}"
        )
        assert surname is not None and surname.text.startswith("TODO:")


class TestIprHolderConversion:
    """Tests that iprHolder/iprHolderOrganization map to rightholderPerson/Organization."""

    def test_ipr_holder_becomes_rightholder_person(self):
        root = _convert_and_parse(_RECORD_WITH_IPR_HOLDERS)
        assert root.find(f".//{_ns('rightholderPerson')}") is not None

    def test_ipr_holder_organization_becomes_rightholder_organization(self):
        root = _convert_and_parse(_RECORD_WITH_IPR_HOLDERS)
        assert root.find(f".//{_ns('rightholderOrganization')}") is not None

    def test_rightholder_person_role_value(self):
        """Person role value is rightholder.

        The profile uses inconsistent casing for persons vs organisations;
        this is likely a temporary issue in the profile and may be unified later.
        """
        root = _convert_and_parse(_RECORD_WITH_IPR_HOLDERS)
        for el in root.findall(f".//{_ns('rightholderPerson')}"):
            assert el.find(_ns("role")).text == "rightholder"

    def test_rightholder_organization_role_value(self):
        """Organisation role value is rightHolder.

        The profile uses inconsistent casing for persons vs organisations;
        this is likely a temporary issue in the profile and may be unified later.
        """
        root = _convert_and_parse(_RECORD_WITH_IPR_HOLDERS)
        for el in root.findall(f".//{_ns('rightholderOrganization')}"):
            assert el.find(_ns("role")).text == "rightHolder"

    def test_original_ipr_holder_absent(self):
        root = _convert_and_parse(_RECORD_WITH_IPR_HOLDERS)
        assert root.find(f".//{_ns('iprHolder')}") is None
        assert root.find(f".//{_ns('iprHolderOrganization')}") is None
