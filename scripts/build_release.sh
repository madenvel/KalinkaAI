#!/usr/bin/env bash
# Release build with the git version embedded for display in the server sheet.
#
#   scripts/build_release.sh              # flutter build apk --release
#   scripts/build_release.sh appbundle    # any flutter build target works
#
# On an exact tag the embedded version is clean ("v0.1.0"); otherwise it
# carries the short commit hash and a -dirty marker for uncommitted changes
# ("v0.1.0-3-gabc1234-dirty", or "v0.1.0-gabc1234" before any tag exists),
# so every build is traceable.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! GIT_DESCRIBE=$(git describe --tags --dirty 2>/dev/null); then
  # No tags yet — compose pubspec version + short hash instead.
  PUBSPEC_VERSION=$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml)
  DIRTY=""
  git diff --quiet HEAD 2>/dev/null || DIRTY="-dirty"
  GIT_DESCRIBE="v${PUBSPEC_VERSION}-g$(git rev-parse --short HEAD)${DIRTY}"
fi

TARGET=${1:-apk}
shift || true

echo "Building $TARGET, version: $GIT_DESCRIBE"
exec flutter build "$TARGET" --release --dart-define=GIT_DESCRIBE="$GIT_DESCRIBE" "$@"
