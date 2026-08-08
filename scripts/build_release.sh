#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-1.2.0}"
DIST_DIR="$ROOT/dist"
PKG_NAME="chatterino-yt-chat-${VERSION}.zip"
PKG_PATH="$DIST_DIR/$PKG_NAME"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/package"

cp -r src libs init.lua info.json LICENSE NOTICE.md "$DIST_DIR/package/"

cd "$DIST_DIR/package"
EPOCH="${SOURCE_DATE_EPOCH:-1704067200}"
find . -exec touch -h -d "@${EPOCH}" {} +
LC_ALL=C find . -type f | sort > ../manifest.txt
# TZ=UTC: zip stores local timestamps; pinning the timezone keeps archives
# byte-comparable across build environments.
TZ=UTC zip -X -q "../$PKG_NAME" -@ < ../manifest.txt
cd "$ROOT"

echo "$PKG_PATH"
