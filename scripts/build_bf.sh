#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD_NAME="${1:-AF-H7_nano}"
[[ "$BOARD_NAME" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'Invalid board name' >&2; exit 1; }
BF_ROOT="${ROOT_DIR}/firmware/betaflight"
BOARD_BF_DIR="${ROOT_DIR}/boards/${BOARD_NAME}/betaflight"
[[ -f "$BOARD_BF_DIR/config.h" ]] || { echo "No Betaflight config: $BOARD_NAME" >&2; exit 1; }
[[ -f "$BF_ROOT/Makefile" ]] || {
    echo 'Initialize the pinned source: git submodule update --init --depth 1 -- firmware/betaflight' >&2
    exit 1
}

mkdir -p "$ROOT_DIR/build"
exec 9>"$ROOT_DIR/build/.novax-betaflight.lock"
flock -n 9 || { echo 'Another novaX Betaflight build is running' >&2; exit 1; }
BUILD_ROOT="${NOVAX_BF_BUILD_DIR:-$ROOT_DIR/build/betaflight}"
RELEASE_DIR="${NOVAX_RELEASE_DIR:-$ROOT_DIR/releases/$BOARD_NAME/betaflight}"
CONFIG_ROOT="$BUILD_ROOT/config"
mkdir -p "$CONFIG_ROOT/configs/$BOARD_NAME" "$BUILD_ROOT/obj"
cmp -s "$BOARD_BF_DIR/config.h" "$CONFIG_ROOT/configs/$BOARD_NAME/config.h" || \
    cp "$BOARD_BF_DIR/config.h" "$CONFIG_ROOT/configs/$BOARD_NAME/config.h"

# Match this pinned upstream source's compiler. HTTPS verification stays enabled.
# Archive identity is the checksum recorded in Betaflight mk/tools.mk at 3c879a06.
SDK_DIR="${NOVAX_ARM_SDK_ROOT:-$BF_ROOT/tools/arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi}"
if [[ ! -f "$SDK_DIR/bin/arm-none-eabi-gcc" ]]; then
    [[ ! -e "$SDK_DIR" ]] || { echo "Incomplete SDK: $SDK_DIR" >&2; exit 1; }
    SDK_PARENT="$(dirname "$SDK_DIR")"
    mkdir -p "$SDK_PARENT"
    ARCHIVE="$(mktemp "$SDK_PARENT/arm-sdk-XXXXXX.tar.xz")"
    curl --fail --location --proto '=https' --tlsv1.2 \
        'https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz' \
        --output "$ARCHIVE"
    printf '0601a9588bc5b9c99ad2b56133b7f118  %s\n' "$ARCHIVE" | md5sum --check -
    tar xf "$ARCHIVE" -C "$SDK_PARENT"
    # Keep the verified archive for offline restoration; no automatic cleanup.
fi
[[ "$("$SDK_DIR/bin/arm-none-eabi-gcc" -dumpversion)" == 13.3.1 ]] || {
    echo 'Betaflight requires GCC 13.3.1' >&2; exit 1;
}

cd "$BF_ROOT"
# Upstream hex/binary each start a recursive make; parallel top-level goals
# would race over the same object files. Compile once, then reuse that result.
for format in hex binary; do
    make -j"${NOVAX_BUILD_JOBS:-4}" CONFIG="$BOARD_NAME" CONFIG_DIR="$CONFIG_ROOT" \
        ARM_SDK_PREFIX="$SDK_DIR/bin/arm-none-eabi-" \
        OBJECT_DIR="$BUILD_ROOT/obj/main" BIN_DIR="$BUILD_ROOT/obj" "$format"
done

shopt -s nullglob
artifacts=("$BUILD_ROOT"/obj/betaflight_*_"${BOARD_NAME}".hex "$BUILD_ROOT"/obj/betaflight_*_"${BOARD_NAME}".bin)
[[ ${#artifacts[@]} -eq 2 ]] || { echo 'Expected exactly one HEX and one BIN' >&2; exit 1; }
mkdir -p "$RELEASE_DIR"
for artifact in "${artifacts[@]}"; do
    [[ -s "$artifact" ]] || { echo "Empty artifact: $artifact" >&2; exit 1; }
    cp "$artifact" "$RELEASE_DIR/"
done
echo "Betaflight build outputs in $RELEASE_DIR"
