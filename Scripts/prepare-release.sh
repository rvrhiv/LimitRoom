#!/bin/bash
# Stamp only the CI checkout; never commit generated release metadata to main.
set -euo pipefail

limitroom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
limitroom_version="${1:?Usage: prepare-release.sh VERSION}"
limitroom_repo=rvrhiv/LimitRoom
limitroom_version_pattern='^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$'
[[ $# == 1 && "$limitroom_version" =~ $limitroom_version_pattern ]] || {
  echo 'Use a new stable version such as 0.7.0, without a v prefix or leading zeros.' >&2
  exit 2
}
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == "$limitroom_repo" && -n "${GITHUB_OUTPUT:-}" ]] || {
  echo 'Release preparation runs only in the official GitHub Actions checkout.' >&2
  exit 1
}
cd "$limitroom_root"
limitroom_commit="$(git rev-parse HEAD)"
[[ "$limitroom_commit" =~ ^[0-9a-f]{40}$ ]]
[[ "$(gh api "repos/$limitroom_repo/git/ref/heads/main" --jq '.object.sha')" == "$limitroom_commit" ]] || {
  echo 'main changed before preparation. Start a new workflow run.' >&2
  exit 1
}

# API failures must not be mistaken for a first release or an unused tag.
limitroom_existing="$(gh api "repos/$limitroom_repo/releases?per_page=100" --paginate --jq '.[].tag_name')"
if printf '%s\n' "$limitroom_existing" | /usr/bin/grep -Fxq "v$limitroom_version"; then
  echo 'This release already exists, including possible drafts. Inspect it before retrying.' >&2
  exit 1
fi
limitroom_refs="$(gh api "repos/$limitroom_repo/git/matching-refs/tags/v$limitroom_version" --jq '.[].ref')"
if printf '%s\n' "$limitroom_refs" | /usr/bin/grep -Fxq "refs/tags/v$limitroom_version"; then
  echo 'This tag already exists. Choose a new version.' >&2
  exit 1
fi
limitroom_published="$(gh api "repos/$limitroom_repo/releases?per_page=100" --paginate --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name')"
limitroom_previous_tag=''
limitroom_number=1
if [[ -n "$limitroom_published" ]]; then
  limitroom_previous_tag="$(gh api "repos/$limitroom_repo/releases/latest" --jq '.tag_name')"
  limitroom_previous_version="${limitroom_previous_tag#v}"
  [[ "$limitroom_previous_tag" == "v$limitroom_previous_version" && "$limitroom_previous_version" =~ $limitroom_version_pattern ]]
  IFS=. read -r -a limitroom_requested_parts <<< "$limitroom_version"
  IFS=. read -r -a limitroom_previous_parts <<< "$limitroom_previous_version"
  limitroom_newer=false
  for limitroom_index in 0 1 2; do
    if (( limitroom_requested_parts[limitroom_index] > limitroom_previous_parts[limitroom_index] )); then
      limitroom_newer=true
      break
    elif (( limitroom_requested_parts[limitroom_index] < limitroom_previous_parts[limitroom_index] )); then
      break
    fi
  done
  [[ "$limitroom_newer" == true ]] || {
    echo "Version must be newer than $limitroom_previous_version." >&2
    exit 1
  }

  # Read the exact published feed, not a moving latest URL. Never reset the
  # monotonic build number when metadata is missing or cannot be retrieved.
  limitroom_feed="$(/usr/bin/curl --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 60 --retry 3 \
    "https://github.com/$limitroom_repo/releases/download/$limitroom_previous_tag/appcast.xml")"
  [[ "$(printf '%s' "$limitroom_feed" | /usr/bin/xmllint --nonet --xpath 'count(/rss/channel/item)' -)" == 1 ]]
  [[ "$(printf '%s' "$limitroom_feed" | /usr/bin/xmllint --nonet --xpath 'string(/rss/channel/item/*[local-name()="shortVersionString"])' -)" == "$limitroom_previous_version" ]]
  limitroom_previous_number="$(printf '%s' "$limitroom_feed" | /usr/bin/xmllint --nonet --xpath 'string(/rss/channel/item/*[local-name()="version"])' -)"
  [[ "$limitroom_previous_number" =~ ^[1-9][0-9]{0,8}$ ]] || {
    echo 'The previous release has an invalid build number.' >&2
    exit 1
  }
  (( limitroom_previous_number < 999999999 )) || {
    echo 'The supported build number range is exhausted.' >&2
    exit 1
  }
  limitroom_number=$((limitroom_previous_number + 1))
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $limitroom_version" "$limitroom_root/Config/App-Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $limitroom_number" "$limitroom_root/Config/App-Info.plist"
{
  printf 'version=%s\n' "$limitroom_version"
  printf 'build=%s\n' "$limitroom_number"
  printf 'commit=%s\n' "$limitroom_commit"
  printf 'previous_tag=%s\n' "$limitroom_previous_tag"
} >> "$GITHUB_OUTPUT"
printf 'Preparing LimitRoom %s (build %s) from main at %s\n' "$limitroom_version" "$limitroom_number" "$limitroom_commit"
