#!/bin/bash
# Development builds are ad-hoc signed. Public releases require Developer ID and
# a Keychain notarytool profile; never put Apple account credentials in this repo.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-development}"
case "$mode" in
  development) identity="-" ;;
  release)
    : "${FINEKEYS_SIGN_IDENTITY:?Set to your Developer ID Application identity}"
    : "${FINEKEYS_NOTARY_PROFILE:?Set to your notarytool Keychain profile name}"
    case "$FINEKEYS_SIGN_IDENTITY" in
      "Developer ID Application:"*) identity="$FINEKEYS_SIGN_IDENTITY" ;;
      *) echo "A Developer ID Application signing identity is required." >&2; exit 1 ;;
    esac
    ;;
  *) echo "Usage: $0 [development|release]" >&2; exit 1 ;;
esac
build_root="${FINEKEYS_BUILD_DIR:-$project_root/.build}"
mkdir -p "$build_root"
staging="$(mktemp -d "$build_root/package.XXXXXX")"
xcodebuild -project "$project_root/FineKeys.xcodeproj" -scheme FineKeys \
  -configuration Release -derivedDataPath "$build_root/DerivedData" \
  ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="$identity" build > "$staging/build.log" 2>&1 || {
    cat "$staging/build.log" >&2; exit 1;
  }
app="$staging/FineKeys.app"
ditto "$build_root/DerivedData/Build/Products/Release/FineKeys.app" "$app"
if [[ "$mode" == release ]]; then
  codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
codesign --verify --strict "$app"
architectures="$(lipo -archs "$app/Contents/MacOS/FineKeys")"
for required_arch in arm64 x86_64; do
  [[ " $architectures " == *" $required_arch "* ]] || { echo "Missing architecture: $required_arch" >&2; exit 1; }
done
minimum=$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app/Contents/Info.plist")
[[ "$minimum" == "13.0" ]] || { echo "Unexpected deployment target: $minimum" >&2; exit 1; }
if [[ "$mode" == release ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$app" "$staging/notary-upload.zip"
  xcrun notarytool submit "$staging/notary-upload.zip" --keychain-profile "$FINEKEYS_NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose "$app"
fi
# Package only after all gates pass; a failed notarization never yields a release ZIP.
archive="$staging/FineKeys-$mode.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
echo "Created: $archive"
