#!/bin/sh

set -eu

WATCHMAN_VERSION="${WATCHMAN_VERSION:-v2026.05.04.00}"
ARCH="$(uname -m)"
SOURCE_URL="${WATCHMAN_SOURCE_URL:-https://github.com/facebook/watchman/archive/refs/tags/${WATCHMAN_VERSION}.tar.gz}"

if [ -n "${WATCHMAN_DOWNLOAD_URL:-}" ]; then
    INSTALL_METHOD="archive"
    DOWNLOAD_URL="$WATCHMAN_DOWNLOAD_URL"
else
    case "$ARCH" in
        x86_64|amd64)
            INSTALL_METHOD="archive"
            DOWNLOAD_URL="https://github.com/facebook/watchman/releases/download/${WATCHMAN_VERSION}/watchman-${WATCHMAN_VERSION}-linux.zip"
            ;;
        aarch64|arm64)
            INSTALL_METHOD="source"
            ;;
        *)
            echo "Error: unsupported architecture ${ARCH}."
            echo "Set WATCHMAN_DOWNLOAD_URL to a compatible archive if you need Watchman in this container."
            exit 1
            ;;
    esac
fi

TMPDIR=$(mktemp -d)
ARCHIVE_PATH="$TMPDIR/watchman.zip"
SOURCE_ARCHIVE_PATH="$TMPDIR/watchman.tar.gz"

cleanup() {
    rm -rf "$TMPDIR"
}

trap cleanup EXIT

setup_runtime_dir() {
    install -d /usr/local/var/run/watchman
    chmod 2777 /usr/local/var/run/watchman
}

if [ "$INSTALL_METHOD" = "source" ]; then
    echo "Building Watchman ${WATCHMAN_VERSION} from source for ${ARCH}"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        cargo \
        git \
        python3 \
        python3-pip

    if ! command -v pip >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
        ln -s "$(command -v pip3)" /usr/local/bin/pip
    fi

    curl -fsSL "$SOURCE_URL" -o "$SOURCE_ARCHIVE_PATH"
    tar -xzf "$SOURCE_ARCHIVE_PATH" -C "$TMPDIR"

    SOURCE_DIR="$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d -name 'watchman-*' | head -n 1 || true)"

    if [ -z "$SOURCE_DIR" ]; then
        echo "Error: Watchman source archive did not contain the expected directory"
        exit 1
    fi

    cd "$SOURCE_DIR"
    PIP_BREAK_SYSTEM_PACKAGES=1 python3 build/fbcode_builder/getdeps.py --allow-system-packages install-system-deps --recursive watchman
    PREFIX=/usr/local ./autogen.sh

    if [ ! -x built/bin/watchman ] || [ ! -x built/bin/watchmanctl ]; then
        echo "Error: Watchman source build did not produce the expected binaries"
        exit 1
    fi

    install -d /usr/local/bin
    install built/bin/watchman /usr/local/bin/watchman
    install built/bin/watchmanctl /usr/local/bin/watchmanctl
    setup_runtime_dir

    if [ -d built/lib ] && find built/lib -mindepth 1 -maxdepth 1 | read -r _; then
        install -d /usr/local/lib
        cp -a built/lib/. /usr/local/lib/
    fi

    if command -v ldconfig >/dev/null 2>&1; then
        ldconfig
    fi

    exit 0
fi

echo "Downloading Watchman from: $DOWNLOAD_URL"
curl -fsSL "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"
unzip -q "$ARCHIVE_PATH" -d "$TMPDIR"

WATCHMAN_BIN="$(find "$TMPDIR" -path '*/bin/watchman' -type f | head -n 1 || true)"

if [ -z "$WATCHMAN_BIN" ]; then
    echo "Error: Watchman archive did not contain the expected binaries"
    exit 1
fi

EXTRACT_DIR="${WATCHMAN_BIN%/bin/watchman}"

if [ ! -x "$EXTRACT_DIR/bin/watchman" ] || [ ! -x "$EXTRACT_DIR/bin/watchmanctl" ]; then
    echo "Error: Watchman archive did not contain the expected binaries"
    exit 1
fi

install -d /usr/local/bin /usr/local/lib
install "$EXTRACT_DIR/bin/watchman" /usr/local/bin/watchman
install "$EXTRACT_DIR/bin/watchmanctl" /usr/local/bin/watchmanctl
setup_runtime_dir
cp -a "$EXTRACT_DIR/lib/." /usr/local/lib/

if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
