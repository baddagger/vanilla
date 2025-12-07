#!/bin/bash

set -e

cd "$(dirname "$0")/.."

PROJECT_NAME="Vanilla Player"
SCHEME_NAME="Vanilla Player"
ARCH=$(uname -m)
DMG_NAME="VanillaPlayer-$ARCH.dmg"
BUILD_DIR="build"

echo "🔨 Building $PROJECT_NAME..."
xcodebuild clean build \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME_NAME" \
  -destination 'platform=macOS' \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR"

APP_PATH="$BUILD_DIR/Build/Products/Release/$PROJECT_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build failed: App not found at $APP_PATH"
  exit 1
fi

echo "📦 Creating DMG..."
rm -rf dmg_temp
mkdir -p dmg_temp
cp -R "$APP_PATH" dmg_temp/
ln -s /Applications dmg_temp/Applications

rm -f "$DMG_NAME"
hdiutil create -volname "$PROJECT_NAME" \
  -srcfolder dmg_temp \
  -ov -format UDZO \
  "$DMG_NAME"

rm -rf dmg_temp

echo "✅ DMG created: $DMG_NAME"
