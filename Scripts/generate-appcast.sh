#!/bin/bash
# Generate appcast.xml for Sparkle auto-updates
# Usage: ./generate-appcast.sh <version> <build> <tag> <dmg_file> <signature> <repo>

set -e

VERSION="$1"
BUILD="$2"
TAG="$3"
DMG_FILE="$4"
SIGNATURE="$5"
REPO="${6:-baddagger/vanilla}"

if [ -z "$VERSION" ] || [ -z "$BUILD" ] || [ -z "$TAG" ] || [ -z "$DMG_FILE" ]; then
  echo "Usage: $0 <version> <build> <tag> <dmg_file> [signature] [repo]"
  exit 1
fi

DMG_SIZE=$(stat -f%z "$DMG_FILE" 2>/dev/null || stat -c%s "$DMG_FILE")
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${DMG_FILE}"
PUB_DATE=$(date -R)

# Extract release notes from CHANGELOG.md
RELEASE_NOTES="Bug fixes and improvements."
if [ -f "CHANGELOG.md" ]; then
  NOTES=$(awk -v ver="$VERSION" '
    /^###? \[/ { if (found) exit; if ($0 ~ "\\[" ver "\\]") { found=1; next } }
    found && NF { print }
  ' CHANGELOG.md | head -20)
  [ -n "$NOTES" ] && RELEASE_NOTES="$NOTES"
fi

# Build signature attribute if provided
SIG_ATTR=""
[ -n "$SIGNATURE" ] && SIG_ATTR="sparkle:edSignature=\"${SIGNATURE}\""

# Generate appcast.xml
cat > appcast.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Vanilla Player Updates</title>
        <link>https://github.com/${REPO}/releases</link>
        <description>Most recent updates to Vanilla Player</description>
        <language>en</language>
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <description><![CDATA[${RELEASE_NOTES}]]></description>
            <sparkle:version>${BUILD}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <enclosure url="${DOWNLOAD_URL}"
                       length="${DMG_SIZE}"
                       type="application/octet-stream"
                       ${SIG_ATTR} />
        </item>
    </channel>
</rss>
EOF

echo "✅ Generated appcast.xml for version ${VERSION}"
