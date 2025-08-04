#!/usr/bin/env bash
set -euo pipefail

GIT_VERSION="2.39.5-0+deb12u2"
ARCH="amd64"
URL="https://deb.debian.org/debian/pool/main/g/git/git_${GIT_VERSION}_${ARCH}.deb"
DEST_DIR="$(dirname "$0")/../tools/git"
TMP_DIR="$(mktemp -d)"

mkdir -p "$DEST_DIR"

curl -L "$URL" -o "$TMP_DIR/git.deb"
dpkg-deb -x "$TMP_DIR/git.deb" "$TMP_DIR/extract"
cp "$TMP_DIR/extract/usr/bin/git" "$DEST_DIR/git"
chmod +x "$DEST_DIR/git"
rm -rf "$TMP_DIR"
