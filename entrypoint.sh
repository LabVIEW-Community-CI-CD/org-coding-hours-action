#!/bin/sh
set -e

VERSION="${GIT_HOURS_VERSION:-v0.1.2}"
URL="https://github.com/trinhminhtriet/git-hours/releases/download/${VERSION}/git-hours_Linux_x86_64.tar.gz"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Download and extract git-hours
curl -sL "$URL" -o "$TMP_DIR/git-hours.tar.gz"
tar -xzf "$TMP_DIR/git-hours.tar.gz" -C "$TMP_DIR"
chmod +x "$TMP_DIR/git-hours"
mv "$TMP_DIR/git-hours" /usr/local/bin/git-hours

exec /app/OrgCodingHoursCLI "$@"
