#!/bin/bash
# Generate appcast.xml for Sparkle auto-updates with multi-arch support
# Usage: ./generate-appcast.sh <version> <build> <tag> <dmg_directory> <repo>
# Environment: SPARKLE_PRIVATE_KEY (optional, for signing)

set -e

VERSION="$1"
BUILD="$2"
TAG="$3"
DMG_DIR="$4"
REPO="${5:-baddagger/vanilla}"
MIN_OS="${6:-15.0}"

if [ -z "$VERSION" ] || [ -z "$BUILD" ] || [ -z "$TAG" ] || [ -z "$DMG_DIR" ]; then
  echo "Usage: $0 <version> <build> <tag> <dmg_directory> [repo] [min_os]"
  exit 1
fi

PUB_DATE=$(date -R)

# Extract release notes
RELEASE_NOTES="Bug fixes and improvements."
if [ -f "CHANGELOG.md" ]; then
  NOTES=$(awk -v ver="$VERSION" '
    /^###? \[/ { if (found) exit; if ($0 ~ "\\[" ver "\\]") { found=1; next } }
    found && NF { print }
  ' CHANGELOG.md | head -20)
  [ -n "$NOTES" ] && RELEASE_NOTES="$NOTES"
fi

# Detect Sparkle tools
SPARKLE_SIGN_CMD="./sparkle_tools/bin/sign_update"
if [ ! -f "$SPARKLE_SIGN_CMD" ]; then
    # Fallback or check path
    SPARKLE_SIGN_CMD="sparkle_tools/bin/sign_update"
fi

echo "Generating appcast for version $VERSION ($BUILD) with Min OS $MIN_OS..."

# Start XML
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
            <sparkle:minimumSystemVersion>${MIN_OS}</sparkle:minimumSystemVersion>
EOF

# Process each DMG in the directory
for DMG_PATH in "$DMG_DIR"/*.dmg; do
    [ -e "$DMG_PATH" ] || continue
    
    DMG_FILE=$(basename "$DMG_PATH")
    DMG_SIZE=$(stat -f%z "$DMG_PATH" 2>/dev/null || stat -c%s "$DMG_PATH")
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${DMG_FILE}"
    
    # Sign it if key is available
    SIG_ATTR=""
    if [ -n "$SPARKLE_PRIVATE_KEY" ] && [ -f "$SPARKLE_SIGN_CMD" ]; then
        echo "Signing $DMG_FILE..."
        SIGNATURE=$(echo "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_SIGN_CMD" -f - -p "$DMG_PATH")
        SIG_ATTR="sparkle:edSignature=\"${SIGNATURE}\""
    elif [ -n "$SPARKLE_PRIVATE_KEY" ]; then
        echo "Warning: Private key present but sign_update tool not found at $SPARKLE_SIGN_CMD"
    fi
    
    # Determine Arch for sparkle:cpu
    CPU_ATTR=""
    if [[ "$DMG_FILE" == *"arm64"* ]]; then
        CPU_ATTR="sparkle:cpu=\"arm64\""
    elif [[ "$DMG_FILE" == *"x86_64"* ]]; then
        CPU_ATTR="sparkle:cpu=\"x86_64\""
    fi
    
    echo "  Adding enclosure for $DMG_FILE ($CPU_ATTR)"
    
    # Append enclosure
    cat >> appcast.xml << EOF
            <enclosure url="${DOWNLOAD_URL}"
                       length="${DMG_SIZE}"
                       type="application/octet-stream"
                       ${CPU_ATTR}
                       ${SIG_ATTR} />
EOF
done

# Close XML
cat >> appcast.xml << EOF
        </item>
    </channel>
</rss>
EOF

echo "✅ Generated appcast.xml with $(grep -c "<enclosure" appcast.xml) enclosures"
