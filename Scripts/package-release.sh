#!/bin/bash
set -euo pipefail

limitroom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
limitroom_version="${1:?Usage: package-release.sh VERSION BUILD}"
limitroom_number="${2:?Usage: package-release.sh VERSION BUILD}"
[[ "$limitroom_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$limitroom_number" =~ ^[1-9][0-9]*$ ]] || exit 2
limitroom_app="$limitroom_root/build/LimitRoom.app"
limitroom_plist="$limitroom_app/Contents/Info.plist"
limitroom_output="$limitroom_root/build/releases/$limitroom_version"

[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$limitroom_plist")" == com.rvrhiv.LimitRoom ]]
for limitroom_info in "$limitroom_plist" "$limitroom_root/Config/App-Info.plist"; do
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$limitroom_info")" == "$limitroom_version" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$limitroom_info")" == "$limitroom_number" ]]
done
for limitroom_setting in SURequireSignedFeed SUVerifyUpdateBeforeExtraction; do
  [[ "$(/usr/libexec/PlistBuddy -c "Print :$limitroom_setting" "$limitroom_plist")" == true ]]
done
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$limitroom_plist")" == "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$limitroom_root/Config/App-Info.plist")" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$limitroom_plist")" == https://github.com/rvrhiv/LimitRoom/releases/latest/download/appcast.xml ]]
[[ -f "$limitroom_root/docs/releases/$limitroom_version.md" ]]
/usr/bin/codesign --verify --deep --strict "$limitroom_app"
for limitroom_binary in "$limitroom_app/Contents/MacOS/LimitRoom" "$limitroom_app/Contents/Helpers/limitroom-claude-bridge" "$limitroom_app/Contents/Frameworks/Sparkle.framework/Sparkle"; do
  /usr/bin/lipo "$limitroom_binary" -verify_arch arm64 x86_64
done
if [[ -e "$limitroom_output" ]]; then
  echo 'Refusing to overwrite an existing release directory.' >&2
  exit 1
fi
mkdir -p "$limitroom_output"
/usr/bin/ditto -c -k --keepParent --norsrc "$limitroom_app" "$limitroom_output/LimitRoom-$limitroom_version.zip"
cp "$limitroom_root/docs/releases/$limitroom_version.md" "$limitroom_output/LimitRoom-$limitroom_version.md"
echo "Packaged $limitroom_version ($limitroom_number). Signing is still required."
