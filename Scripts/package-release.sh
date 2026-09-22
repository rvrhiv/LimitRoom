#!/bin/bash
set -euo pipefail

limitroom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
limitroom_version="${1:?Usage: package-release.sh VERSION BUILD}"
limitroom_number="${2:?Usage: package-release.sh VERSION BUILD}"
[[ "$limitroom_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$limitroom_number" =~ ^[1-9][0-9]*$ ]] || exit 2
limitroom_app="$limitroom_root/build/LimitRoom.app"
limitroom_plist="$limitroom_app/Contents/Info.plist"
limitroom_output="$limitroom_root/build/releases/$limitroom_version"

if [[ "$(/usr/libexec/PlistBuddy -c 'Print :LimitRoomBuildFlavor' "$limitroom_plist")" != distribution ]]; then
  echo 'Only distribution builds can be packaged. Run: bash Scripts/build-app.sh Release distribution' >&2
  exit 1
fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$limitroom_plist")" == LimitRoom ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$limitroom_plist")" == LimitRoom ]]
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
if [[ -e "$limitroom_root/docs/releases/$limitroom_version.md" && ! -s "$limitroom_root/docs/releases/$limitroom_version.md" ]]; then
  echo 'Supplied release notes must not be empty.' >&2
  exit 1
fi
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
if [[ -f "$limitroom_root/docs/releases/$limitroom_version.md" ]]; then
  cp "$limitroom_root/docs/releases/$limitroom_version.md" "$limitroom_output/LimitRoom-$limitroom_version.md"
fi
echo "Packaged $limitroom_version ($limitroom_number). Signing is still required."
