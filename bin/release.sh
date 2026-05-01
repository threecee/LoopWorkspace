#!/usr/bin/env bash
# bin/release.sh — archive MyLoop With Watch and upload to TestFlight Internal Testing.
#
# Required env vars (set in ~/.zshrc):
#   ASC_KEY_PATH       — path to the App Store Connect API key .p8 file
#   ASC_KEY_ID         — 10-char Key ID
#   ASC_KEY_ISSUER_ID  — UUID Issuer ID
#
# Versioning:
#   LOOP_MARKETING_VERSION is the single source of truth, read from
#   VersionOverride.xcconfig (workspace-level). Loop's Info.plist files
#   substitute $(LOOP_MARKETING_VERSION) into CFBundleShortVersionString.
#   CURRENT_PROJECT_VERSION is auto-set to git commit count of LoopWorkspace.
#   Both are passed as xcodebuild build-setting overrides.

set -euo pipefail

cd "$(dirname "$0")/.."

: "${ASC_KEY_PATH:?ASC_KEY_PATH not set; source ~/.zshrc}"
: "${ASC_KEY_ID:?ASC_KEY_ID not set}"
: "${ASC_KEY_ISSUER_ID:?ASC_KEY_ISSUER_ID not set}"

# Read LOOP_MARKETING_VERSION (POSIX [[:space:]] for BSD sed compat — D.1a lesson)
MARKETING_VERSION=$(grep -E '^LOOP_MARKETING_VERSION[[:space:]]*=' VersionOverride.xcconfig | sed -E 's/^LOOP_MARKETING_VERSION[[:space:]]*=[[:space:]]*//' | tr -d '[:space:]')
if [ -z "$MARKETING_VERSION" ]; then
  echo "ERROR: could not read LOOP_MARKETING_VERSION from VersionOverride.xcconfig"
  exit 1
fi
if ! echo "$MARKETING_VERSION" | grep -qE '^[0-9]+(\.[0-9]+){0,2}$'; then
  echo "ERROR: LOOP_MARKETING_VERSION='$MARKETING_VERSION' is not 1-3 period-separated integers"
  exit 1
fi

BUILD=$(git rev-list --count HEAD)
WORKSPACE="LoopWorkspace.xcworkspace"
SCHEME="LoopWorkspace"
ARCHIVE_PATH="build/MyLoop.xcarchive"
EXPORT_PATH="build/export"

if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: uncommitted changes (in main repo or submodules). Commit/stash first."
  exit 1
fi

echo "==> Releasing MyLoop With Watch $MARKETING_VERSION (build $BUILD) on branch $(git rev-parse --abbrev-ref HEAD) (commit $(git rev-parse --short HEAD))"

rm -rf build && mkdir -p build

echo "==> Archiving (multi-target: iOS app + watch + extensions)..."
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_KEY_ISSUER_ID" \
  LOOP_MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=8YPHY526TJ

echo "==> Exporting + uploading to App Store Connect..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_KEY_ISSUER_ID"

echo ""
echo "==> Build $BUILD ($MARKETING_VERSION) uploaded."
echo "    Open https://appstoreconnect.apple.com/apps → MyLoop With Watch → TestFlight"
echo "    in ~10-30 min (multi-target IPAs take longer than single-target) for processing-complete."
