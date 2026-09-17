#!/bin/bash
# Builds the OpenFlux Go core (liboflux.a / liboflux.h) for iOS from the
# upstream backend repository, and drops it into ios-app/Lib/.
#
# This repo (OF-IOS) contains ONLY the iOS frontend — no Go source is
# vendored here. The backend is fetched fresh from upstream at a pinned
# commit every time this script runs, so it's never out of sync with what
# the frontend was built and tested against, and there's nothing to keep
# updated by hand.
#
# Requirements: git, Go 1.26+, Xcode (XCODE_PATH env var, defaults to
# /Applications/Xcode.app).
set -e

UPSTREAM_URL="https://github.com/saharev1/OpenFlux.git"
UPSTREAM_REF="ef3d6ef281d56a5a792be1a381d004040b68596d"  # ios-testflight branch

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/.backend-src"

echo "==> Fetching backend from $UPSTREAM_URL @ $UPSTREAM_REF"
rm -rf "$WORK"
git clone "$UPSTREAM_URL" "$WORK"
git -C "$WORK" checkout "$UPSTREAM_REF"

echo "==> Building liboflux.a (iOS arm64)"
"$WORK/build_ios.sh"

echo "==> Copying into ios-app/Lib/"
mkdir -p "$ROOT/ios-app/Lib"
cp "$WORK/output/ios/liboflux.a" "$ROOT/ios-app/Lib/liboflux.a"
cp "$WORK/output/ios/liboflux.h" "$ROOT/ios-app/Lib/liboflux.h"

echo ""
echo "Backend ready: ios-app/Lib/liboflux.a (+ .h)"
echo "Next: cd ios-app && xcodegen generate"
