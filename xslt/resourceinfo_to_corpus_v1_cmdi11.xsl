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

  <!-- Root element: re-namespace to CMDI 1.2 envelope, set CMDVersion="1.2" -->
  <xsl:template match="cmd11:CMD">
    <xsl:element name="CMD" namespace="{$ENVELOPE_NS}">
      <xsl:attribute name="CMDVersion">1.2</xsl:attribute>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- General: all other CMDI 1.1 elements -> CMDI 1.2 envelope namespace -->
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

  <!-- Profile elements (descendants of Components): re-namespace to new profile NS -->
  <xsl:template match="cmd11:Components//*" priority="1">
    <xsl:element name="{local-name()}" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Rename root component: resourceInfo -> resourceInfo-corpus-v1 -->
  <xsl:template match="cmd11:resourceInfo" priority="2">
    <xsl:element name="resourceInfo-corpus-v1" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="node()"/>
    </xsl:element>
  </xsl:template>

  <!-- identificationInfo: drop metaShareId/identifier/url, reorder -->
  <xsl:template match="cmd11:identificationInfo" priority="2">
    <xsl:element name="identificationInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:resourceName"/>
      <xsl:apply-templates select="cmd11:resourceShortName"/>
      <xsl:apply-templates select="cmd11:description"/>
    </xsl:element>
  </xsl:template>

  <!-- distributionInfo: add empty accessInfo, restructure, drop iprHolder -->
  <xsl:template match="cmd11:distributionInfo" priority="2">
    <xsl:element name="distributionInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:availability"/>
      <xsl:apply-templates select="cmd11:availabilityStartDate"/>
      <xsl:apply-templates select="cmd11:availabilityEndDate"/>
      <xsl:element name="accessInfo" namespace="{$NEW_PROFILE_NS}"/>
      <xsl:apply-templates select="cmd11:licenceInfo"/>
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
      <xsl:for-each select="cmd11:licence">
        <xsl:element name="licenseType" namespace="{$NEW_PROFILE_NS}">
          <xsl:call-template name="map-licence">
            <xsl:with-param name="val" select="."/>
          </xsl:call-template>
        </xsl:element>
      </xsl:for-each>
      <!-- licenseLink included for CC and CLARIN licenses; omitted for unknown
           values (e.g. underNegotiation) - the validate step will flag these. -->
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
      <xsl:apply-templates select="cmd11:distributionRightsHolderPerson"/>
      <xsl:apply-templates select="cmd11:distributionRightsHolderOrganization"/>
    </xsl:element>
  </xsl:template>

  <!-- Map old licence value to new licenseType string -->
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
      <!-- Minimum required modifier sets per the licenseType pattern -->
      <xsl:when test="$val = 'CLARIN_ACA'">CLARIN ACA +ID +BY +NORED</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA-NC'">CLARIN ACA +ID +BY +NC +NORED</xsl:when>
      <xsl:when test="$val = 'CLARIN_RES'">CLARIN RES +ID +PLAN +BY +NORED</xsl:when>
      <xsl:when test="$val = 'AGPL'">AGPL</xsl:when>
      <xsl:when test="$val = 'GPL'">GPL</xsl:when>
      <xsl:when test="$val = 'LGPL'">LGPL</xsl:when>
      <xsl:when test="$val = 'MIT'">MIT</xsl:when>
      <!-- Unmapped values preserved with :: prefix as allowed by the pattern -->
      <xsl:otherwise>:: <xsl:value-of select="$val"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Canonical URL for known licence values -->
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
      <!-- No URL for unknown values; licenseLink is omitted and validate will flag it -->
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
