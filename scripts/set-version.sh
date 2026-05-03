#!/usr/bin/env bash
#
# set-version.sh — bump iOS app version + auto-increment build number.
#
# Usage:
#   ./scripts/set-version.sh <marketing_version> [build_number]
#
# Examples:
#   ./scripts/set-version.sh 1.2.3       # sets MARKETING_VERSION=1.2.3, build=current+1
#   ./scripts/set-version.sh 2.0         # sets MARKETING_VERSION=2.0, build=current+1
#   ./scripts/set-version.sh 1.2.3 42    # sets MARKETING_VERSION=1.2.3, build=42
#
# Updates every MARKETING_VERSION + CURRENT_PROJECT_VERSION occurrence in
# Dibba.xcodeproj/project.pbxproj (Debug + Release across all targets).

set -euo pipefail

# Resolve repo root relative to this script so it works from any cwd.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PBXPROJ="$REPO_ROOT/Dibba.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
    echo "error: project.pbxproj not found at $PBXPROJ" >&2
    exit 1
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "usage: $0 <marketing_version> [build_number]" >&2
    echo "  marketing_version: e.g. 1.2.3 or 2.0" >&2
    echo "  build_number: optional explicit build (defaults to current+1)" >&2
    exit 1
fi

NEW_MARKETING="$1"

# Validate marketing version: digits.dotted (1, 1.2, 1.2.3, 10.20.30)
if ! [[ "$NEW_MARKETING" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "error: marketing version '$NEW_MARKETING' must look like 1, 1.2, or 1.2.3" >&2
    exit 1
fi

# Read current values (assume all occurrences match — they should).
CURRENT_MARKETING=$(grep -m1 -E '^[[:space:]]*MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = (.+);.*/\1/')
CURRENT_BUILD=$(grep -m1 -E '^[[:space:]]*CURRENT_PROJECT_VERSION = ' "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = (.+);.*/\1/')

if [[ -z "$CURRENT_MARKETING" || -z "$CURRENT_BUILD" ]]; then
    echo "error: could not read current MARKETING_VERSION / CURRENT_PROJECT_VERSION from pbxproj" >&2
    exit 1
fi

if [[ $# -eq 2 ]]; then
    NEW_BUILD="$2"
    if ! [[ "$NEW_BUILD" =~ ^[0-9]+$ ]]; then
        echo "error: build number '$NEW_BUILD' must be a positive integer" >&2
        exit 1
    fi
else
    NEW_BUILD=$((CURRENT_BUILD + 1))
fi

# In-place edit. macOS sed needs '' after -i. Update every occurrence.
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $NEW_MARKETING;/g" "$PBXPROJ"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"

# Sanity check: count occurrences to make sure nothing got lost.
MARKETING_COUNT=$(grep -cE '^[[:space:]]*MARKETING_VERSION = ' "$PBXPROJ")
BUILD_COUNT=$(grep -cE '^[[:space:]]*CURRENT_PROJECT_VERSION = ' "$PBXPROJ")

echo "iOS version bumped:"
echo "  MARKETING_VERSION:       $CURRENT_MARKETING -> $NEW_MARKETING  (${MARKETING_COUNT} entries)"
echo "  CURRENT_PROJECT_VERSION: $CURRENT_BUILD -> $NEW_BUILD  (${BUILD_COUNT} entries)"
echo ""
echo "Next steps:"
echo "  1. git diff Dibba.xcodeproj/project.pbxproj  # review"
echo "  2. xcodebuild  # verify"
echo "  3. Archive in Xcode and upload to App Store Connect"
