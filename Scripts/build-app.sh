#!/bin/bash
set -euo pipefail

limitroom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
limitroom_configuration="${1:-Release}"
limitroom_flavor="${2:-development}"
if (( $# > 2 )); then
  echo 'Usage: build-app.sh [Debug|Release] [development|distribution]' >&2
  exit 2
fi
case "$limitroom_configuration" in Debug|Release) ;; *) echo 'Use Debug or Release' >&2; exit 2;; esac
case "$limitroom_flavor" in
  development) limitroom_name='LimitRoom Dev' ;;
  distribution)
    [[ "$limitroom_configuration" == Release ]] || { echo 'Distribution builds require Release.' >&2; exit 2; }
    limitroom_name=LimitRoom ;;
  *) echo 'Use development or distribution' >&2; exit 2 ;;
esac
limitroom_build="$limitroom_root/build"
limitroom_products="$limitroom_build/DerivedData/Build/Products/$limitroom_configuration"
limitroom_product_app="$limitroom_products/$limitroom_name.app"
limitroom_app="$limitroom_build/$limitroom_name.app"
limitroom_bundle_identifier='com.rvrhiv.LimitRoom'
limitroom_staging_root="$limitroom_build/LimitRoom-packaging.noindex"
limitroom_staging_directory=''
limitroom_staged_app=''
limitroom_previous_app=''
limitroom_rollback_armed=false
limitroom_promoted=false

limitroom_die() {
  echo "$*" >&2
  exit 1
}

limitroom_is_running() {
  local limitroom_candidate="$1"
  local limitroom_executable="$limitroom_candidate/Contents/MacOS/LimitRoom"
  local limitroom_command

  while IFS= read -r limitroom_command; do
    if [[ "$limitroom_command" == "$limitroom_executable" || "$limitroom_command" == "$limitroom_executable"\ * ]]; then
      return 0
    fi
  done < <(/bin/ps -axo command=)
  return 1
}

limitroom_validate_app() {
  local limitroom_candidate="$1"
  local limitroom_expected_name="$2"
  local limitroom_expected_flavor="$3"
  local limitroom_marker_required="$4"
  local limitroom_info="$limitroom_candidate/Contents/Info.plist"
  local limitroom_candidate_parent
  local limitroom_build_physical

  [[ -e "$limitroom_candidate" || -L "$limitroom_candidate" ]] || limitroom_die "Missing app bundle: $limitroom_candidate"
  [[ ! -L "$limitroom_candidate" && -d "$limitroom_candidate" ]] || limitroom_die "Refusing symlink or non-directory app bundle: $limitroom_candidate"
  [[ ! -L "$limitroom_info" && -f "$limitroom_info" ]] || limitroom_die "Refusing app bundle without a regular Info.plist: $limitroom_candidate"

  limitroom_candidate_parent="$(cd -- "$(dirname -- "$limitroom_candidate")" && pwd -P)"
  limitroom_build_physical="$(cd -- "$limitroom_build" && pwd -P)"
  case "$limitroom_candidate_parent/" in
    "$limitroom_build_physical"/*) ;;
    *) limitroom_die "Refusing app bundle outside the local build directory: $limitroom_candidate" ;;
  esac

  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$limitroom_info")" == "$limitroom_bundle_identifier" ]] ||
    limitroom_die "Refusing app bundle with an unexpected bundle identifier: $limitroom_candidate"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$limitroom_info")" == "$limitroom_expected_name" ]] ||
    limitroom_die "Refusing app bundle with an unexpected display name: $limitroom_candidate"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :LimitRoomBuildFlavor' "$limitroom_info")" == "$limitroom_expected_flavor" ]] ||
    limitroom_die "Refusing app bundle with an unexpected build flavor: $limitroom_candidate"
  [[ ! -L "$limitroom_candidate/Contents/MacOS/LimitRoom" && -f "$limitroom_candidate/Contents/MacOS/LimitRoom" ]] ||
    limitroom_die "Refusing app bundle without the expected executable: $limitroom_candidate"

  if [[ "$limitroom_marker_required" == required ]]; then
    if [[ -L "$limitroom_candidate/Contents/Resources/LimitRoom-local-build" || -L "$limitroom_candidate/Contents/LimitRoom-local-build" ]]; then
      limitroom_die "Refusing app bundle with a symlinked ownership marker: $limitroom_candidate"
    fi
    if [[ ! -f "$limitroom_candidate/Contents/Resources/LimitRoom-local-build" && ! -f "$limitroom_candidate/Contents/LimitRoom-local-build" ]]; then
      limitroom_die "Refusing app bundle not created by this script: $limitroom_candidate"
    fi
  fi

  if limitroom_is_running "$limitroom_candidate"; then
    limitroom_die "Refusing to replace or remove a running app bundle: $limitroom_candidate"
  fi
}

limitroom_cleanup_staging() {
  local limitroom_status=$?
  local limitroom_preserve_staging=false

  if [[ "$limitroom_rollback_armed" == true && "$limitroom_promoted" == false ]]; then
    if [[ ! -e "$limitroom_previous_app" && ! -L "$limitroom_previous_app" && -d "$limitroom_app" && -d "$limitroom_staged_app" ]]; then
      # The first rename did not happen; the old stable app is still in place.
      :
    elif [[ ! -d "$limitroom_previous_app" || -L "$limitroom_previous_app" ]]; then
      echo "Rollback failed because the previous app is missing or unsafe. Preserving recovery data: $limitroom_staging_directory" >&2
      limitroom_preserve_staging=true
      limitroom_status=1
    elif [[ -e "$limitroom_app" || -L "$limitroom_app" ]]; then
      echo "Rollback refused because the destination unexpectedly exists. Previous app preserved at: $limitroom_previous_app" >&2
      limitroom_preserve_staging=true
      limitroom_status=1
    elif ! /bin/mv "$limitroom_previous_app" "$limitroom_app"; then
      echo "Rollback failed. Previous app preserved at: $limitroom_previous_app" >&2
      limitroom_preserve_staging=true
      limitroom_status=1
    fi
  fi
  if [[ "$limitroom_preserve_staging" == false && -n "$limitroom_staging_directory" && -d "$limitroom_staging_directory" && ! -L "$limitroom_staging_directory" ]]; then
    /bin/rm -rf "$limitroom_staging_directory"
  fi
  trap - EXIT
  exit "$limitroom_status"
}

trap limitroom_cleanup_staging EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Refuse build-path indirection before xcodebuild can write through it.
for limitroom_build_directory in \
  "$limitroom_build" \
  "$limitroom_build/DerivedData" \
  "$limitroom_build/DerivedData/Build" \
  "$limitroom_build/DerivedData/Build/Products" \
  "$limitroom_products"; do
  if [[ -L "$limitroom_build_directory" ]]; then
    limitroom_die "Refusing symlinked build directory: $limitroom_build_directory"
  fi
  if [[ -e "$limitroom_build_directory" && ! -d "$limitroom_build_directory" ]]; then
    limitroom_die "Refusing non-directory build path: $limitroom_build_directory"
  fi
done
if [[ -L "$limitroom_product_app" ]]; then
  limitroom_die "Refusing symlinked Xcode product: $limitroom_product_app"
fi
if [[ -e "$limitroom_app" || -L "$limitroom_app" ]]; then
  limitroom_validate_app "$limitroom_app" "$limitroom_name" "$limitroom_flavor" required
fi
if [[ "$limitroom_flavor" == development ]]; then
  for limitroom_existing_product in \
    "$limitroom_build/DerivedData/Build/Products/Debug/LimitRoom Dev.app" \
    "$limitroom_build/DerivedData/Build/Products/Release/LimitRoom Dev.app"; do
    if [[ -e "$limitroom_existing_product" || -L "$limitroom_existing_product" ]]; then
      limitroom_validate_app "$limitroom_existing_product" 'LimitRoom Dev' development unmarked
    fi
  done
elif [[ -e "$limitroom_product_app" || -L "$limitroom_product_app" ]]; then
  limitroom_validate_app "$limitroom_product_app" "$limitroom_name" "$limitroom_flavor" unmarked
fi

xcodebuild -project "$limitroom_root/LimitRoom.xcodeproj" -scheme LimitRoom \
  -configuration "$limitroom_configuration" -destination 'generic/platform=macOS' \
  -derivedDataPath "$limitroom_build/DerivedData" CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO \
  LIMITROOM_BUILD_FLAVOR="$limitroom_flavor" build -quiet

limitroom_validate_app "$limitroom_product_app" "$limitroom_name" "$limitroom_flavor" unmarked

# Package and verify a fresh app before touching the current local copy.
if [[ -e "$limitroom_staging_root" || -L "$limitroom_staging_root" ]]; then
  [[ ! -L "$limitroom_staging_root" && -d "$limitroom_staging_root" ]] ||
    limitroom_die "Refusing unsafe packaging directory: $limitroom_staging_root"
else
  mkdir -p "$limitroom_staging_root"
fi
limitroom_staging_directory="$(/usr/bin/mktemp -d "$limitroom_staging_root/package.XXXXXX")"
limitroom_staged_app="$limitroom_staging_directory/$limitroom_name.app"
limitroom_previous_app="$limitroom_staging_directory/previous.app"

mkdir -p "$limitroom_staged_app/Contents/MacOS" "$limitroom_staged_app/Contents/Helpers" \
  "$limitroom_staged_app/Contents/Resources" "$limitroom_staged_app/Contents/Frameworks"
/usr/bin/ditto "$limitroom_product_app/Contents/Frameworks/Sparkle.framework" "$limitroom_staged_app/Contents/Frameworks/Sparkle.framework"
touch "$limitroom_staged_app/Contents/Resources/LimitRoom-local-build"
cp "$limitroom_product_app/Contents/MacOS/LimitRoom" "$limitroom_staged_app/Contents/MacOS/LimitRoom"
cp "$limitroom_products/limitroom-claude-bridge" "$limitroom_staged_app/Contents/Helpers/limitroom-claude-bridge"
cp "$limitroom_product_app/Contents/Info.plist" "$limitroom_staged_app/Contents/Info.plist"
cp "$limitroom_product_app/Contents/Resources/LimitRoom.icns" "$limitroom_staged_app/Contents/Resources/LimitRoom.icns"
cp "$limitroom_root/Resources/Sparkle-LICENSE.txt" "$limitroom_staged_app/Contents/Resources/Sparkle-LICENSE.txt"
cp "$limitroom_root/LICENSE" "$limitroom_staged_app/Contents/Resources/LICENSE"
cp "$limitroom_root/THIRD_PARTY_NOTICES.md" "$limitroom_staged_app/Contents/Resources/THIRD_PARTY_NOTICES.md"
/usr/bin/codesign --force --sign - "$limitroom_staged_app/Contents/Helpers/limitroom-claude-bridge"
# Xcode strips development headers from the embedded framework; seal that
# container again. Its nested vendor-signed helpers are preserved unchanged.
/usr/bin/codesign --force --sign - "$limitroom_staged_app/Contents/Frameworks/Sparkle.framework"
/usr/bin/codesign --force --sign - "$limitroom_staged_app"
/usr/bin/codesign --verify --deep --strict "$limitroom_staged_app"
limitroom_validate_app "$limitroom_staged_app" "$limitroom_name" "$limitroom_flavor" required

# Refuse an unknown, installed, symlinked, or running destination before promotion.
if [[ -e "$limitroom_app" || -L "$limitroom_app" ]]; then
  limitroom_validate_app "$limitroom_app" "$limitroom_name" "$limitroom_flavor" required
fi

# Preflight every exact cleanup target before replacing the current app. This
# keeps the previous packaged app intact if a stale Xcode product is unknown.
if [[ "$limitroom_flavor" == development ]]; then
  for limitroom_obsolete_app in \
    "$limitroom_build/DerivedData/Build/Products/Debug/LimitRoom Dev.app" \
    "$limitroom_build/DerivedData/Build/Products/Release/LimitRoom Dev.app"; do
    if [[ -e "$limitroom_obsolete_app" || -L "$limitroom_obsolete_app" ]]; then
      limitroom_validate_app "$limitroom_obsolete_app" 'LimitRoom Dev' development unmarked
    fi
  done
fi

if [[ -e "$limitroom_app" ]]; then
  # Arm before the rename: a signal can run the EXIT trap immediately after mv.
  limitroom_rollback_armed=true
  /bin/mv "$limitroom_app" "$limitroom_previous_app"
fi
if [[ -e "$limitroom_app" || -L "$limitroom_app" ]]; then
  limitroom_die "Destination unexpectedly exists before promotion. Previous app preserved at: $limitroom_previous_app"
fi
if ! /bin/mv "$limitroom_staged_app" "$limitroom_app"; then
  limitroom_die "Failed to promote the verified app: $limitroom_app"
fi
limitroom_promoted=true

if [[ -d "$limitroom_previous_app" ]]; then
  /bin/rm -rf "$limitroom_previous_app"
fi

# Xcode's build products are runnable copies. A successful development package
# keeps only the stable build/LimitRoom Dev.app, while preserving intermediates.
if [[ "$limitroom_flavor" == development ]]; then
  for limitroom_obsolete_app in \
    "$limitroom_build/DerivedData/Build/Products/Debug/LimitRoom Dev.app" \
    "$limitroom_build/DerivedData/Build/Products/Release/LimitRoom Dev.app"; do
    if [[ -e "$limitroom_obsolete_app" || -L "$limitroom_obsolete_app" ]]; then
      limitroom_validate_app "$limitroom_obsolete_app" 'LimitRoom Dev' development unmarked
      /bin/rm -rf "$limitroom_obsolete_app"
    fi
  done
fi

echo "Built $limitroom_flavor app: $limitroom_app"
echo "Preview: open '$limitroom_app' --args --demo"
