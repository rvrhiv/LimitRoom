#!/bin/bash
# Only run on a trusted checkout. Do not enable shell tracing around secrets.
set +x
set -euo pipefail

limitroom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
limitroom_version="${1:?Usage: sign-release.sh VERSION BUILD}"
limitroom_number="${2:?Usage: sign-release.sh VERSION BUILD}"
[[ "$limitroom_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$limitroom_number" =~ ^[1-9][0-9]*$ ]] || exit 2
limitroom_output="$limitroom_root/build/releases/$limitroom_version"
limitroom_tools="$limitroom_root/.build/artifacts/sparkle/Sparkle/bin"
limitroom_archive="$limitroom_output/LimitRoom-$limitroom_version.zip"
limitroom_feed="$limitroom_output/appcast.xml"
[[ -f "$limitroom_archive" && -x "$limitroom_tools/generate_appcast" ]]
[[ -s "$limitroom_output/LimitRoom-$limitroom_version.md" ]] || {
  echo 'Nonempty release notes are required before signing.' >&2
  exit 1
}

limitroom_sign() {
  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$1" --ed-key-file - "${@:2}"
  else
    "$1" --account com.rvrhiv.LimitRoom.release "${@:2}"
  fi
}
if [[ "${CI:-}" == true && -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo 'The release signing secret is missing.' >&2
  exit 1
fi
limitroom_sign "$limitroom_tools/generate_appcast" \
  --download-url-prefix "https://github.com/rvrhiv/LimitRoom/releases/download/v$limitroom_version/" \
  --release-notes-url-prefix "https://github.com/rvrhiv/LimitRoom/releases/download/v$limitroom_version/" \
  --link https://github.com/rvrhiv/LimitRoom/releases \
  --maximum-deltas 0 --maximum-versions 1 "$limitroom_output"

# Validate generated metadata and signatures before the publishing step.
[[ -f "$limitroom_feed" ]]
[[ "$(/usr/bin/xmllint --xpath 'count(/rss/channel/item)' "$limitroom_feed")" == 1 ]]
[[ "$(/usr/bin/xmllint --xpath 'string(/rss/channel/item/*[local-name()="version"])' "$limitroom_feed")" == "$limitroom_number" ]]
[[ "$(/usr/bin/xmllint --xpath 'string(/rss/channel/item/*[local-name()="shortVersionString"])' "$limitroom_feed")" == "$limitroom_version" ]]
[[ "$(/usr/bin/xmllint --xpath 'string(/rss/channel/item/enclosure/@url)' "$limitroom_feed")" == "https://github.com/rvrhiv/LimitRoom/releases/download/v$limitroom_version/LimitRoom-$limitroom_version.zip" ]]
limitroom_signature="$(/usr/bin/xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="edSignature"])' "$limitroom_feed")"
[[ -n "$limitroom_signature" ]]
limitroom_sign "$limitroom_tools/sign_update" --verify "$limitroom_archive" "$limitroom_signature"
limitroom_sign "$limitroom_tools/sign_update" --verify "$limitroom_feed"
cd "$limitroom_output"
/usr/bin/shasum -a 256 "LimitRoom-$limitroom_version.zip" "LimitRoom-$limitroom_version.md" appcast.xml > SHA256SUMS
echo "Verified signed release: $limitroom_version ($limitroom_number)"
