#!/bin/sh

set -eu

WATCHMAN_VERSION="${WATCHMAN_VERSION:-v2026.05.04.00}"
DOWNLOAD_URL="${WATCHMAN_DOWNLOAD_URL:-https://github.com/facebook/watchman/releases/download/${WATCHMAN_VERSION}/watchman-${WATCHMAN_VERSION}-linux.zip}"
TMPDIR=$(mktemp -d)
ARCHIVE_PATH="$TMPDIR/watchman.zip"
EXTRACT_DIR="$TMPDIR/watchman-${WATCHMAN_VERSION}-linux"

cleanup() {
    rm -rf "$TMPDIR"
}

trap cleanup EXIT

echo "Downloading Watchman from: $DOWNLOAD_URL"
curl -fsSL "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"
unzip -q "$ARCHIVE_PATH" -d "$TMPDIR"

if [ ! -x "$EXTRACT_DIR/bin/watchman" ]; then
    echo "Error: Watchman archive did not contain the expected binaries"
    exit 1
fi

install -d /usr/local/bin /usr/local/lib
install "$EXTRACT_DIR/bin/watchman" /usr/local/bin/watchman
install "$EXTRACT_DIR/bin/watchmanctl" /usr/local/bin/watchmanctl
cp -a "$EXTRACT_DIR/lib/." /usr/local/lib/

if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
