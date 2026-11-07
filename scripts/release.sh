#!/bin/bash
# Builds a release of Undistra: universal app, DMG, zip and checksums in dist/.
#
#   scripts/release.sh 1.0.1
#
# Without extra settings the app is ad-hoc signed: it works, but other Macs show
# "Apple could not verify Undistra" on first launch.
#
# To make downloads open with no warning, sign and notarize with a Developer ID:
#   1. Create a "Developer ID Application" certificate (Xcode → Settings → Accounts → Manage Certificates).
#   2. Save notarization credentials once (uses an app-specific password from appleid.apple.com):
#        xcrun notarytool store-credentials undistra --apple-id YOU@EXAMPLE.COM --team-id TEAMID
#   3. Run:
#        DEVELOPER_ID="Developer ID Application: NAME (TEAMID)" NOTARY_PROFILE=undistra scripts/release.sh 1.0.1
set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh <version>, e.g. 1.0.1}"
cd "$(dirname "$0")/.."

BUILD_DIR="build/Release-build"
APP="$BUILD_DIR/Build/Products/Release/Undistra.app"
DIST="dist"
DMG="$DIST/Undistra-$VERSION.dmg"
ZIP="$DIST/Undistra-$VERSION.zip"

step() { printf "\n\033[1;35m▸ %s\033[0m\n" "$1"; }

step "Setting version to $VERSION"
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g" Undistra.xcodeproj/project.pbxproj
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" Undistra.xcodeproj/project.pbxproj

step "Building universal Release app"
rm -rf "$BUILD_DIR"
xcodebuild -project Undistra.xcodeproj -scheme Undistra -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR" build -quiet
lipo -archs "$APP/Contents/MacOS/Undistra"

notarize() { # $1 = file to submit
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  step "Signing with $DEVELOPER_ID"
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"

  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    step "Notarizing the app (this can take a few minutes)"
    ditto -c -k --keepParent "$APP" "$BUILD_DIR/notarize.zip"
    notarize "$BUILD_DIR/notarize.zip"
    xcrun stapler staple "$APP"
  else
    echo "NOTARY_PROFILE not set: signed but not notarized, so Macs will still show a warning."
  fi
else
  echo "DEVELOPER_ID not set: the app is ad-hoc signed, so other Macs show a warning on first launch."
fi

step "Packaging"
rm -rf "$DIST" && mkdir -p "$DIST/dmg-stage"
ditto "$APP" "$DIST/dmg-stage/Undistra.app"
ln -s /Applications "$DIST/dmg-stage/Applications"
hdiutil create -volname "Undistra $VERSION" -srcfolder "$DIST/dmg-stage" -ov -format UDZO -fs HFS+ "$DMG" -quiet
rm -rf "$DIST/dmg-stage"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    step "Notarizing the DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
  fi
fi

(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > SHA256SUMS.txt)

step "Done"
ls -lh "$DIST"
cat "$DIST/SHA256SUMS.txt"
echo
echo "Publish with:"
echo "  gh release create v$VERSION $DMG $ZIP $DIST/SHA256SUMS.txt --title \"Undistra $VERSION\" --notes-file <notes.md> --draft"
