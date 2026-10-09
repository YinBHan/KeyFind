#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR
elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

for tool in swift sips iconutil hdiutil codesign ditto; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    print -u2 "KeyFind build requires '$tool' on macOS."
    exit 1
  fi
done
if [[ ! -x /usr/libexec/PlistBuddy ]]; then
  print -u2 "KeyFind build requires /usr/libexec/PlistBuddy on macOS."
  exit 1
fi

swift build -c release --product KeyFindApp

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")"
OUTPUT_ROOT="${KEYFIND_BUILD_OUTPUT_DIR:-$PROJECT_DIR/.build/distribution}"
APP="$OUTPUT_ROOT/KeyFind.app"
DIST_DIR="$OUTPUT_ROOT/dist"
if [[ -e "$APP" || -e "$DIST_DIR/KeyFind-$VERSION-macOS.zip" || -e "$DIST_DIR/KeyFind-$VERSION-macOS.dmg" ]]; then
  print -u2 "Refusing to overwrite an existing package in $OUTPUT_ROOT. Set KEYFIND_BUILD_OUTPUT_DIR to a new directory."
  exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DIST_DIR"
PRODUCT_DIR="$(swift build -c release --product KeyFindApp --show-bin-path)"
if [[ ! -x "$PRODUCT_DIR/KeyFindApp" ]]; then
  print -u2 "KeyFindApp was not found in SwiftPM's release bin path: $PRODUCT_DIR"
  exit 1
fi
if [[ ! -d "$PRODUCT_DIR/KeyFind_KeyFindCore.bundle" ]]; then
  print -u2 "KeyFindCore resources were not found beside the release executable."
  exit 1
fi
cp "$PRODUCT_DIR/KeyFindApp" "$APP/Contents/MacOS/KeyFindApp"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -R "$PRODUCT_DIR/KeyFind_KeyFindCore.bundle" "$APP/Contents/Resources/"

ICONSET="$(mktemp -d "${TMPDIR:-/tmp}/keyfind-iconset.XXXXXX.iconset")"
trap 'rm -rf "$ICONSET"' EXIT
mkdir -p "$ICONSET"
ICON_SOURCE="$PROJECT_DIR/Resources/KeyFind-icon.svg"
for size in 16 32 128 256 512; do
  /usr/bin/sips -s format png -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  /usr/bin/sips -s format png -z "$double" "$double" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/KeyFind.icns"

chmod +x "$APP/Contents/MacOS/KeyFindApp"
SIGNING_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP" >/dev/null

ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST_DIR/KeyFind-$VERSION-macOS.zip"
/usr/bin/hdiutil create -volname "KeyFind $VERSION" -srcfolder "$APP" -ov -format UDZO "$DIST_DIR/KeyFind-$VERSION-macOS.dmg" >/dev/null
echo "Built $APP"
echo "Created $DIST_DIR/KeyFind-$VERSION-macOS.zip"
echo "Created $DIST_DIR/KeyFind-$VERSION-macOS.dmg"
