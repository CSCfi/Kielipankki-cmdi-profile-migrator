<?xml version="1.0" encoding="UTF-8"?>
<!--
  CMDI 1.1 -> CMDI 1.2 conversion: resourceInfo -> resourceInfo-corpus-v1.

  CMDI 1.1 uses a single namespace for both envelope and profile elements
  (http://www.clarin.eu/cmd/).  This stylesheet outputs CMDI 1.2:
    - Envelope elements (CMD, Header, Resources, Components, ...) in
      http://www.clarin.eu/cmd/1
    - Profile elements (everything inside Components) in
      http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1778593302234
    - CMDVersion="1.2" set on the root element
    - ComponentId attributes dropped (CMDI 1.2 uses namespace-based identity)
  The structural conversion rules (resourceInfo rename, identificationInfo and
  distributionInfo restructure, availability and licence mapping) are the same
  as in the 1.2 stylesheet.
-->
<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:cmd11="http://www.clarin.eu/cmd/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    exclude-result-prefixes="xsl cmd11">

  <xsl:variable name="ENVELOPE_NS" select="'http://www.clarin.eu/cmd/1'"/>
  <xsl:variable name="NEW_PROFILE_NS"
    select="'http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1778593302234'"/>

  <!-- ============================================================
       GENERAL RULES
       ============================================================ -->

  <!-- Pass text, comments, and processing instructions through unchanged -->
  <xsl:template match="text()|comment()|processing-instruction()">
    <xsl:copy/>
  </xsl:template>

  <!-- Pass all attributes through unchanged (specific templates override below) -->
  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>

  <!-- Drop ComponentId attributes: component identity in CMDI 1.2 is namespace-based -->
  <xsl:template match="@ComponentId"/>

  <!-- Drop CMDVersion: set explicitly on the root element -->
  <xsl:template match="@CMDVersion"/>

  <!-- Root element: re-namespace to CMDI 1.2 envelope, set CMDVersion="1.2".
       IsPartOfList is a direct CMD child in CMDI 1.2, not inside Resources. -->
  <xsl:template match="cmd11:CMD">
    <xsl:element name="CMD" namespace="{$ENVELOPE_NS}">
      <xsl:attribute name="CMDVersion">1.2</xsl:attribute>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="cmd11:Header"/>
      <xsl:element name="Resources" namespace="{$ENVELOPE_NS}">
        <xsl:apply-templates select="cmd11:Resources/*[not(self::cmd11:IsPartOfList)]"/>
      </xsl:element>
      <xsl:apply-templates select="cmd11:Resources/cmd11:IsPartOfList"/>
      <xsl:apply-templates select="cmd11:Components"/>
    </xsl:element>
  </xsl:template>

  <!-- General: all CMDI 1.1 envelope elements -> CMDI 1.2 envelope namespace -->
  <xsl:template match="cmd11:*">
    <xsl:element name="{local-name()}" namespace="{$ENVELOPE_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Update schemaLocation: CMDI 1.2 envelope schema + new profile XSD -->
  <xsl:template match="@xsi:schemaLocation">
    <xsl:attribute name="xsi:schemaLocation">
      <xsl:value-of select="concat(
        'http://www.clarin.eu/cmd/1 https://infra.clarin.eu/CMDI/1.x/xsd/cmd-envelop.xsd ',
        $NEW_PROFILE_NS, ' ',
        'https://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/1.2/profiles/clarin.eu:cr1:p_1778593302234/xsd'
      )"/>
    </xsl:attribute>
  </xsl:template>

  <!-- Update profile ID in header -->
  <xsl:template match="cmd11:MdProfile">
    <xsl:element name="MdProfile" namespace="{$ENVELOPE_NS}">
      <xsl:text>clarin.eu:cr1:p_1778593302234</xsl:text>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       PROFILE ELEMENTS (inside Components)
       ============================================================ -->

  <!-- General: re-namespace old profile elements to new profile NS -->
  <xsl:template match="cmd11:Components//*" priority="1">
    <xsl:element name="{local-name()}" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Root component: explicit child ordering; generate required elements when absent -->
  <xsl:template match="cmd11:resourceInfo" priority="2">
    <xsl:element name="resourceInfo-corpus-v1" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:identificationInfo"/>
      <xsl:apply-templates select="cmd11:distributionInfo"/>
      <xsl:apply-templates select="cmd11:contactPerson"/>
      <xsl:apply-templates select="cmd11:metadataInfo"/>
      <xsl:apply-templates select="cmd11:resourceDocumentationInfo"/>
      <!-- resourceCreationInfo is required in the new profile -->
      <xsl:choose>
        <xsl:when test="cmd11:resourceCreationInfo">
          <xsl:apply-templates select="cmd11:resourceCreationInfo"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="stub-resource-creation-info"/>
        </xsl:otherwise>
      </xsl:choose>
      <!-- Merge multiple old relationInfo elements into one new-style relationInfo -->
      <xsl:if test="cmd11:relationInfo">
        <xsl:element name="relationInfo" namespace="{$NEW_PROFILE_NS}">
          <xsl:for-each select="cmd11:relationInfo">
            <xsl:element name="relation" namespace="{$NEW_PROFILE_NS}">
              <xsl:apply-templates select="cmd11:relationType"/>
              <xsl:element name="relatedResourceLink" namespace="{$NEW_PROFILE_NS}">
                <xsl:variable name="nameuri"
                  select="cmd11:relatedResource/cmd11:targetResourceNameURI"/>
                <xsl:choose>
                  <xsl:when test="contains($nameuri, ' https://')">
                    <xsl:value-of select="concat('https://', substring-after($nameuri, ' https://'))"/>
                  </xsl:when>
                  <xsl:when test="contains($nameuri, ' http://')">
                    <xsl:value-of select="concat('http://', substring-after($nameuri, ' http://'))"/>
                  </xsl:when>
                  <xsl:otherwise><xsl:value-of select="$nameuri"/></xsl:otherwise>
                </xsl:choose>
              </xsl:element>
            </xsl:element>
          </xsl:for-each>
        </xsl:element>
      </xsl:if>
      <!-- corpusInfo is required; generate a stub when absent -->
      <xsl:choose>
        <xsl:when test="cmd11:corpusInfo">
          <xsl:apply-templates select="cmd11:corpusInfo"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="stub-corpus-info"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- identificationInfo: reorder children, drop metaShareId/identifier/url,
       strip xml:lang from resourceShortName (plain xs:string in new profile) -->
  <xsl:template match="cmd11:identificationInfo" priority="2">
    <xsl:element name="identificationInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:resourceName"/>
      <xsl:for-each select="cmd11:resourceShortName[1]">
        <xsl:element name="resourceShortName" namespace="{$NEW_PROFILE_NS}">
          <xsl:value-of select="."/>
        </xsl:element>
      </xsl:for-each>
      <xsl:apply-templates select="cmd11:description"/>
    </xsl:element>
  </xsl:template>

  <!-- distributionInfo: restructure children, add mandatory copyrightInfo -->
  <xsl:template match="cmd11:distributionInfo" priority="2">
    <xsl:element name="distributionInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:availability"/>
      <xsl:apply-templates select="cmd11:availabilityStartDate"/>
      <xsl:apply-templates select="cmd11:availabilityEndDate"/>
      <xsl:element name="accessInfo" namespace="{$NEW_PROFILE_NS}"/>
      <!-- licenseInfo is required (min=1); max=1 so only take first licenceInfo -->
      <xsl:choose>
        <xsl:when test="cmd11:licenceInfo">
          <xsl:apply-templates select="cmd11:licenceInfo[1]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="stub-license-info"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:element name="copyrightInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="copyrightStatus" namespace="{$NEW_PROFILE_NS}">unknown</xsl:element>
        <xsl:element name="description" namespace="{$NEW_PROFILE_NS}">
          <xsl:attribute name="xml:lang">en</xsl:attribute>
          <xsl:text>Copyright status not specified in original record.</xsl:text>
        </xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- Map old availability enum to new enum -->
  <xsl:template match="cmd11:distributionInfo/cmd11:availability" priority="2">
    <xsl:element name="availability" namespace="{$NEW_PROFILE_NS}">
      <xsl:choose>
        <xsl:when test=". = 'available-unrestrictedUse'">Available</xsl:when>
        <xsl:when test=". = 'available-restrictedUse'">Available</xsl:when>
        <xsl:when test=". = 'notAvailableThroughMetaShare'">Archived</xsl:when>
        <xsl:when test=". = 'underNegotiation'">Preliminary</xsl:when>
        <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- licenceInfo -> licenseInfo: remap licence values, migrate rights holders -->
  <xsl:template match="cmd11:licenceInfo" priority="2">
    <xsl:element name="licenseInfo" namespace="{$NEW_PROFILE_NS}">
      <!-- licenseType (min=1) and licenseLink (min=1) required; add stubs if no licence -->
      <xsl:choose>
        <xsl:when test="cmd11:licence">
          <xsl:for-each select="cmd11:licence">
            <xsl:element name="licenseType" namespace="{$NEW_PROFILE_NS}">
              <xsl:call-template name="map-licence">
                <xsl:with-param name="val" select="."/>
              </xsl:call-template>
            </xsl:element>
          </xsl:for-each>
          <xsl:for-each select="cmd11:licence">
            <xsl:variable name="url">
              <xsl:call-template name="licence-url">
                <xsl:with-param name="val" select="."/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:if test="$url != ''">
              <xsl:element name="licenseLink" namespace="{$NEW_PROFILE_NS}">
                <xsl:element name="link" namespace="{$NEW_PROFILE_NS}">
                  <xsl:element name="url" namespace="{$NEW_PROFILE_NS}">
                    <xsl:value-of select="$url"/>
                  </xsl:element>
                </xsl:element>
              </xsl:element>
            </xsl:if>
          </xsl:for-each>
          <!-- licenseLink is also required (min=1); if all licence values lacked a URL, add stub -->
          <xsl:variable name="any-url">
            <xsl:for-each select="cmd11:licence">
              <xsl:variable name="u">
                <xsl:call-template name="licence-url"><xsl:with-param name="val" select="."/></xsl:call-template>
              </xsl:variable>
              <xsl:if test="$u != ''">y</xsl:if>
            </xsl:for-each>
          </xsl:variable>
          <xsl:if test="$any-url = ''">
            <xsl:call-template name="stub-license-link"/>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <xsl:element name="licenseType" namespace="{$NEW_PROFILE_NS}">:: unknown</xsl:element>
          <xsl:call-template name="stub-license-link"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="cmd11:distributionRightsHolderPerson"/>
      <xsl:apply-templates select="cmd11:distributionRightsHolderOrganization"/>
    </xsl:element>
  </xsl:template>

  <!-- metadataInfo: drop metadataLanguageName/Id and metadataCreator (latter
       requires sourceOfMetadataRecord before it, which has no old-profile source);
       add metadataRevisionLog (from revision) and metadataRecordInfo (from MdSelfLink) -->
  <xsl:template match="cmd11:metadataInfo" priority="2">
    <xsl:element name="metadataInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:metadataCreationDate"/>
      <xsl:apply-templates select="cmd11:metadataLastDateUpdated"/>
      <xsl:element name="metadataRevisionLog" namespace="{$NEW_PROFILE_NS}">
        <xsl:variable name="rev-date">
          <xsl:choose>
            <xsl:when test="string(cmd11:metadataLastDateUpdated)">
              <xsl:value-of select="cmd11:metadataLastDateUpdated"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="cmd11:metadataCreationDate"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:for-each select="cmd11:revision[string($rev-date)]">
          <xsl:element name="logEntry" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="date" namespace="{$NEW_PROFILE_NS}">
              <xsl:value-of select="$rev-date"/>
            </xsl:element>
            <xsl:element name="note" namespace="{$NEW_PROFILE_NS}">
              <xsl:attribute name="xml:lang">en</xsl:attribute>
              <xsl:value-of select="."/>
            </xsl:element>
          </xsl:element>
        </xsl:for-each>
      </xsl:element>
      <xsl:variable name="selflink"
        select="ancestor::cmd11:CMD/cmd11:Header/cmd11:MdSelfLink"/>
      <xsl:element name="metadataRecordInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="MetadataRecordIdentifier" namespace="{$NEW_PROFILE_NS}">
          <xsl:attribute name="MetadataRecordIdentifierScheme">
            <xsl:choose>
              <xsl:when test="starts-with($selflink, 'urn:')">urn</xsl:when>
              <xsl:when test="starts-with($selflink, 'http://hdl.')">handle</xsl:when>
              <xsl:otherwise>url</xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:value-of select="$selflink"/>
        </xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- resourceCreationInfo: add stub resourceCreatorOrganization when absent -->
  <xsl:template match="cmd11:resourceCreationInfo" priority="2">
    <xsl:element name="resourceCreationInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:creationStartDate"/>
      <xsl:apply-templates select="cmd11:creationEndDate"/>
      <!-- max=1 for both person and org in new profile; take only first -->
      <xsl:choose>
        <xsl:when test="cmd11:resourceCreatorPerson">
          <xsl:apply-templates select="cmd11:resourceCreatorPerson[1]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="stub-creator-person"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="cmd11:resourceCreatorOrganization">
          <xsl:apply-templates select="cmd11:resourceCreatorOrganization[1]"/>
        </xsl:when>
        <xsl:when test="cmd11:resourceCreatorPerson[1]//cmd11:affiliation[1]/cmd11:organizationInfo">
          <xsl:element name="resourceCreatorOrganization" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">resourceCreator</xsl:element>
            <xsl:apply-templates
              select="cmd11:resourceCreatorPerson[1]//cmd11:affiliation[1]/cmd11:organizationInfo[1]"/>
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="stub-creator-organization"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="stub-funding-project"/>
      <xsl:element name="resourceRevisionLog" namespace="{$NEW_PROFILE_NS}"/>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       STUB GENERATORS for required elements missing from source
       ============================================================ -->

  <xsl:template name="stub-resource-creation-info">
    <xsl:element name="resourceCreationInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:call-template name="stub-creator-person"/>
      <xsl:call-template name="stub-creator-organization"/>
      <xsl:call-template name="stub-funding-project"/>
      <xsl:element name="resourceRevisionLog" namespace="{$NEW_PROFILE_NS}"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="stub-funding-project">
    <xsl:element name="fundingProject" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">fundingProject</xsl:element>
      <xsl:element name="projectInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="projectName" namespace="{$NEW_PROFILE_NS}">
          <xsl:attribute name="xml:lang">en</xsl:attribute>
          <xsl:text>Unknown</xsl:text>
        </xsl:element>
        <xsl:element name="fundingType" namespace="{$NEW_PROFILE_NS}">other</xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- Force role first; limit info to [1] (source may have multiple or wrong order) -->
  <xsl:template match="cmd11:resourceCreatorOrganization|cmd11:distributionRightsHolderOrganization|
                       cmd11:licensorOrganization|cmd11:rightholderOrganization|
                       cmd11:resourceCreatorPerson|cmd11:distributionRightsHolderPerson|
                       cmd11:licensorPerson|cmd11:rightholderPerson|
                       cmd11:contactPerson|cmd11:metadataCreator|
                       cmd11:affiliation" priority="2">
    <xsl:element name="{local-name()}" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:role"/>
      <xsl:apply-templates select="*[local-name() != 'role'][1]"/>
    </xsl:element>
  </xsl:template>

  <!-- Documentation containers: role first; add stub role when absent from source;
       suppress entirely when the info child has no content (source data quality) -->
  <xsl:template match="cmd11:documentationStructured|cmd11:documentationUnstructured|
                       cmd11:documentationStructuredWithUrl" priority="2">
    <xsl:variable name="info" select="*[local-name() != 'role'][1]"/>
    <xsl:if test="$info/* or $info/text()[normalize-space()]">
      <xsl:element name="{local-name()}" namespace="{$NEW_PROFILE_NS}">
        <xsl:choose>
          <xsl:when test="cmd11:role">
            <xsl:apply-templates select="cmd11:role"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">documentation</xsl:element>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="$info"/>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- Normalize non-standard Res1/Res2 resource proxy types to Resource -->
  <xsl:template match="cmd11:Res1|cmd11:Res2">
    <xsl:element name="Resource" namespace="{$ENVELOPE_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="stub-license-info">
    <xsl:element name="licenseInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="licenseType" namespace="{$NEW_PROFILE_NS}">:: unknown</xsl:element>
      <xsl:call-template name="stub-license-link"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="stub-license-link">
    <xsl:element name="licenseLink" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="link" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="url" namespace="{$NEW_PROFILE_NS}">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <xsl:template name="stub-corpus-info">
    <xsl:element name="corpusInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="resourceType" namespace="{$NEW_PROFILE_NS}">corpus</xsl:element>
      <xsl:element name="corpusMediaType" namespace="{$NEW_PROFILE_NS}"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="stub-creator-person">
    <xsl:element name="resourceCreatorPerson" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">resourceCreator</xsl:element>
      <xsl:element name="personInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="surname" namespace="{$NEW_PROFILE_NS}">
          <xsl:attribute name="xml:lang">en</xsl:attribute>
          <xsl:text>Unknown</xsl:text>
        </xsl:element>
        <xsl:element name="communicationInfo" namespace="{$NEW_PROFILE_NS}">
          <xsl:element name="email" namespace="{$NEW_PROFILE_NS}">unknown@unknown.example</xsl:element>
        </xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <xsl:template name="stub-creator-organization">
    <xsl:element name="resourceCreatorOrganization" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">resourceCreator</xsl:element>
      <xsl:element name="organizationInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="organizationName" namespace="{$NEW_PROFILE_NS}">
          <xsl:attribute name="xml:lang">en</xsl:attribute>
          <xsl:text>Unknown</xsl:text>
        </xsl:element>
        <xsl:element name="communicationInfo" namespace="{$NEW_PROFILE_NS}">
          <xsl:element name="email" namespace="{$NEW_PROFILE_NS}">unknown@unknown.example</xsl:element>
        </xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       RELATION TYPE MAPPING
       ============================================================ -->

  <!-- Map old relationType free-text to new closed enum -->
  <xsl:template match="cmd11:relationType" priority="2">
    <xsl:element name="relationType" namespace="{$NEW_PROFILE_NS}">
      <xsl:choose>
        <xsl:when test=". = 'IsVariantFormOf'">IsVariantFormOf</xsl:when>
        <xsl:when test=". = 'IsOriginalFormOf'">IsOriginalFormOf</xsl:when>
        <xsl:when test=". = 'IsDerivedFrom'">IsDerivedFrom</xsl:when>
        <xsl:when test=". = 'IsSourceOf'">IsSourceOf</xsl:when>
        <xsl:when test=". = 'IsPreviousVersionOf'">IsPreviousVersionOf</xsl:when>
        <xsl:when test=". = 'IsNewVersionOf'">IsNewVersionOf</xsl:when>
        <xsl:when test=". = 'IsPartOf'">IsPartOf</xsl:when>
        <xsl:when test=". = 'HasPart'">HasPart</xsl:when>
        <xsl:when test=". = 'IsContinuedBy'">IsContinuedBy</xsl:when>
        <xsl:when test=". = 'Continues'">Continues</xsl:when>
        <xsl:when test=". = 'IsCompiledBy'">IsCompiledBy</xsl:when>
        <xsl:when test=". = 'Compiles'">Compiles</xsl:when>
        <xsl:otherwise>Other</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       LICENCE MAPPING
       ============================================================ -->

  <xsl:template name="map-licence">
    <xsl:param name="val"/>
    <xsl:choose>
      <xsl:when test="$val = 'CC-BY'">CC BY</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC'">CC BY-NC</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-ND'">CC BY-NC-ND</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-SA'">CC BY-NC-SA</xsl:when>
      <xsl:when test="$val = 'CC-BY-ND'">CC BY-ND</xsl:when>
      <xsl:when test="$val = 'CC-BY-SA'">CC BY-SA</xsl:when>
      <xsl:when test="$val = 'CC-ZERO'">CC0</xsl:when>
      <xsl:when test="$val = 'CLARIN_PUB'">CLARIN PUB</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA'">CLARIN ACA +ID +BY +NORED</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA-NC'">CLARIN ACA +ID +BY +NC +NORED</xsl:when>
      <xsl:when test="$val = 'CLARIN_RES'">CLARIN RES +ID +PLAN +BY +NORED</xsl:when>
      <xsl:when test="$val = 'AGPL'">AGPL</xsl:when>
      <xsl:when test="$val = 'GPL'">GPL</xsl:when>
      <xsl:when test="$val = 'LGPL'">LGPL</xsl:when>
      <xsl:when test="$val = 'MIT'">MIT</xsl:when>
      <xsl:otherwise>:: <xsl:value-of select="$val"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="licence-url">
    <xsl:param name="val"/>
    <xsl:choose>
      <xsl:when test="$val = 'CC-BY'">https://creativecommons.org/licenses/by/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC'">https://creativecommons.org/licenses/by-nc/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-ND'">https://creativecommons.org/licenses/by-nc-nd/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-SA'">https://creativecommons.org/licenses/by-nc-sa/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-ND'">https://creativecommons.org/licenses/by-nd/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-SA'">https://creativecommons.org/licenses/by-sa/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-ZERO'">https://creativecommons.org/publicdomain/zero/1.0/</xsl:when>
      <xsl:when test="$val = 'CLARIN_PUB'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA-NC'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
      <xsl:when test="$val = 'CLARIN_RES'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
