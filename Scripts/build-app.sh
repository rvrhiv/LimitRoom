#!/bin/bash
set -euo pipefail

limitroom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
limitroom_configuration="${1:-Release}"
case "$limitroom_configuration" in Debug|Release) ;; *) echo 'Use Debug or Release' >&2; exit 2;; esac
limitroom_build="$limitroom_root/build"
limitroom_products="$limitroom_build/DerivedData/Build/Products/$limitroom_configuration"
limitroom_app="$limitroom_build/LimitRoom.app"

xcodebuild -project "$limitroom_root/LimitRoom.xcodeproj" -scheme LimitRoom \
  -configuration "$limitroom_configuration" -destination 'generic/platform=macOS' \
  -derivedDataPath "$limitroom_build/DerivedData" CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO build -quiet

# Package the app and its helper without modifying any installed copy.
if [[ -e "$limitroom_app" && ! -f "$limitroom_app/Contents/Resources/LimitRoom-local-build" && ! -f "$limitroom_app/Contents/LimitRoom-local-build" ]]; then
  echo "Refusing to overwrite an app not created by this script: $limitroom_app" >&2
  exit 1
fi
mkdir -p "$limitroom_app/Contents/MacOS" "$limitroom_app/Contents/Helpers" "$limitroom_app/Contents/Resources"
mkdir -p "$limitroom_app/Contents/Frameworks"
/usr/bin/ditto "$limitroom_products/LimitRoom.app/Contents/Frameworks/Sparkle.framework" "$limitroom_app/Contents/Frameworks/Sparkle.framework"
if [[ -f "$limitroom_app/Contents/LimitRoom-local-build" ]]; then
  mv "$limitroom_app/Contents/LimitRoom-local-build" "$limitroom_app/Contents/Resources/LimitRoom-local-build"
fi
touch "$limitroom_app/Contents/Resources/LimitRoom-local-build"
cp "$limitroom_products/LimitRoom.app/Contents/MacOS/LimitRoom" "$limitroom_app/Contents/MacOS/LimitRoom"
cp "$limitroom_products/limitroom-claude-bridge" "$limitroom_app/Contents/Helpers/limitroom-claude-bridge"
cp "$limitroom_products/LimitRoom.app/Contents/Info.plist" "$limitroom_app/Contents/Info.plist"
cp "$limitroom_products/LimitRoom.app/Contents/Resources/LimitRoom.icns" "$limitroom_app/Contents/Resources/LimitRoom.icns"
cp "$limitroom_root/Resources/Sparkle-LICENSE.txt" "$limitroom_app/Contents/Resources/Sparkle-LICENSE.txt"
/usr/bin/codesign --force --sign - "$limitroom_app/Contents/Helpers/limitroom-claude-bridge"
# Xcode strips development headers from the embedded framework; seal that
# container again. Its nested vendor-signed helpers are preserved unchanged.
/usr/bin/codesign --force --sign - "$limitroom_app/Contents/Frameworks/Sparkle.framework"
/usr/bin/codesign --force --sign - "$limitroom_app"
/usr/bin/codesign --verify --deep --strict "$limitroom_app"
echo "Local app: $limitroom_app"
echo "Preview: open '$limitroom_app' --args --demo"
