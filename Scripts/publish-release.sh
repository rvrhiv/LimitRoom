#!/bin/bash
set -euo pipefail

limitroom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
limitroom_version="${1:?Usage: publish-release.sh VERSION BUILD COMMIT}"
limitroom_number="${2:?Usage: publish-release.sh VERSION BUILD COMMIT}"
limitroom_commit="${3:?Usage: publish-release.sh VERSION BUILD COMMIT}"
[[ "$limitroom_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$limitroom_number" =~ ^[1-9][0-9]*$ && "$limitroom_commit" =~ ^[0-9a-f]{40}$ ]] || exit 2
limitroom_repo=rvrhiv/LimitRoom
limitroom_tag="v$limitroom_version"
limitroom_output="$limitroom_root/build/releases/$limitroom_version"
cd "$limitroom_output"
/usr/bin/shasum -a 256 -c SHA256SUMS
[[ "$(/usr/bin/xmllint --xpath 'string(/rss/channel/item/*[local-name()="version"])' appcast.xml)" == "$limitroom_number" ]]

# Successful API reads are required. Network/auth errors must never mean "absent".
limitroom_existing="$(gh api "repos/$limitroom_repo/releases?per_page=100" --paginate --jq '.[].tag_name')"
if printf '%s\n' "$limitroom_existing" | /usr/bin/grep -Fxq "$limitroom_tag"; then
  echo 'Release already exists. Do not overwrite signed published assets.' >&2
  exit 1
fi
limitroom_refs="$(gh api "repos/$limitroom_repo/git/matching-refs/tags/$limitroom_tag" --jq '.[].ref')"
if printf '%s\n' "$limitroom_refs" | /usr/bin/grep -Fxq "refs/tags/$limitroom_tag"; then
  echo 'Tag already exists. Review it before retrying publication.' >&2
  exit 1
fi
[[ "$(gh api "repos/$limitroom_repo/git/ref/heads/main" --jq '.object.sha')" == "$limitroom_commit" ]]
limitroom_published="$(gh api "repos/$limitroom_repo/releases?per_page=100" --paginate --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name')"
if [[ -n "$limitroom_published" ]]; then
  limitroom_previous="$(/usr/bin/curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    https://github.com/rvrhiv/LimitRoom/releases/latest/download/appcast.xml \
    | /usr/bin/xmllint --xpath 'string(/rss/channel/item/*[local-name()="version"])' -)"
  [[ "$limitroom_previous" =~ ^[1-9][0-9]{0,8}$ && "$limitroom_number" =~ ^[1-9][0-9]{0,8}$ ]]
  if (( limitroom_number <= limitroom_previous )); then
    echo 'Build number must be higher than the latest published build.' >&2
    exit 1
  fi
fi
gh release create "$limitroom_tag" --repo "$limitroom_repo" --target "$limitroom_commit" \
  --draft --title "LimitRoom $limitroom_version" --notes-file "LimitRoom-$limitroom_version.md" \
  "LimitRoom-$limitroom_version.zip" "LimitRoom-$limitroom_version.md" appcast.xml SHA256SUMS
gh release edit "$limitroom_tag" --repo "$limitroom_repo" --draft=false --latest
