#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD_NAME="${1:-AF-F4_nano}"
VEHICLE="${2:-copter}"

AP_ROOT="${ROOT_DIR}/firmware/ardupilot"
RELEASE_DIR="${ROOT_DIR}/releases/${BOARD_NAME}/ardupilot"
BOOTLOADER_DIR="${AP_ROOT}/Tools/bootloaders"
BIN_DIR="${AP_ROOT}/build/${BOARD_NAME}/bin"

case "${VEHICLE}" in
    copter)
        VEHICLE_BIN="arducopter"
        ;;
    plane)
        VEHICLE_BIN="arduplane"
        ;;
    rover)
        VEHICLE_BIN="ardurover"
        ;;
    sub)
        VEHICLE_BIN="ardusub"
        ;;
    tracker)
        VEHICLE_BIN="antennatracker"
        ;;
    blimp)
        VEHICLE_BIN="blimp"
        ;;
    AP_Periph)
        VEHICLE_BIN="AP_Periph"
        ;;
    *)
        echo "Unsupported vehicle target: ${VEHICLE}" >&2
        exit 1
        ;;
esac

mkdir -p "${RELEASE_DIR}"

# Output base name. FC vehicles keep waf's name (arducopter.apj ...) because
# release.sh renames them per tag/vehicle at publish time. AP_Periph boards
# instead get "<board>-v<version>" right here, so the file on disk already says
# WHICH product and WHICH version it is: every peripheral is built from the same
# AP_Periph target and would otherwise land as an identical "AP_Periph.apj"
# (AP-RTK_dual vs AP-RTK_G5H). Version source order mirrors build_ap.sh:
# NOVAX_VERSION env -> boards/<board>/VERSION -> repo VERSION -> dev.
if [[ "${VEHICLE}" == "AP_Periph" ]]; then
    NOVAX_VERSION="${NOVAX_VERSION:-$(cat "${ROOT_DIR}/boards/${BOARD_NAME}/VERSION" 2>/dev/null \
        || cat "${ROOT_DIR}/VERSION" 2>/dev/null || echo dev)}"
    NOVAX_VERSION="$(tr -d '[:space:]' <<< "${NOVAX_VERSION}")"
    OUT_BASE="${BOARD_NAME}-v${NOVAX_VERSION}"
    # stale unnamed copies from older packaging runs would make release.sh see a
    # second ".apj" and treat the board as multi-vehicle -- drop them.
    rm -f "${RELEASE_DIR}"/AP_Periph.apj "${RELEASE_DIR}"/AP_Periph.bin \
          "${RELEASE_DIR}"/AP_Periph.hex "${RELEASE_DIR}"/AP_Periph_with_bl.hex
else
    OUT_BASE="${VEHICLE_BIN}"
fi

copy_if_exists() {
    local src="$1"
    local dst="$2"
    if [[ -f "${src}" ]]; then
        cp -f "${src}" "${dst}"
    fi
}

copy_if_exists "${BOOTLOADER_DIR}/${BOARD_NAME}_bl.bin" "${RELEASE_DIR}/${BOARD_NAME}_bl.bin"
copy_if_exists "${BOOTLOADER_DIR}/${BOARD_NAME}_bl.hex" "${RELEASE_DIR}/${BOARD_NAME}_bl.hex"
copy_if_exists "${BOOTLOADER_DIR}/${BOARD_NAME}_bl.elf" "${RELEASE_DIR}/${BOARD_NAME}_bl.elf"
copy_if_exists "${BIN_DIR}/${VEHICLE_BIN}.apj" "${RELEASE_DIR}/${OUT_BASE}.apj"
copy_if_exists "${BIN_DIR}/${VEHICLE_BIN}.bin" "${RELEASE_DIR}/${OUT_BASE}.bin"
copy_if_exists "${BIN_DIR}/${VEHICLE_BIN}_with_bl.hex" "${RELEASE_DIR}/${OUT_BASE}_with_bl.hex"

# AP_Periph builds emit only .bin/.apj (no combined hex). Generate Intel HEX here:
# app-only, bootloader-only, and a combined bootloader+app hex.
#
# CRITICAL: build the hexes from the CONTIGUOUS .bin images, NOT from the ELF.
# objcopy -O ihex on the ELF omits records for inter-section padding bytes, so
# those addresses are left 0xFF (erased) when a programmer flashes the hex. But
# the app descriptor's CRC was computed by waf over the zero-filled .bin, so a
# hex-flashed app FAILS the bootloader's check_good_firmware() with BAD_CRC and
# NEVER boots (board stays in the bootloader / MAINTENANCE). The .bin is gap-free
# (padding = 0x00), so its hex reproduces the exact CRC'd image and boots.
if [[ "${VEHICLE}" == "AP_Periph" ]]; then
    OBJCOPY="${OBJCOPY:-arm-none-eabi-objcopy}"
    APP_ELF="${BIN_DIR}/AP_Periph"
    APP_BIN="${RELEASE_DIR}/${OUT_BASE}.bin"
    BL_BIN="${RELEASE_DIR}/${BOARD_NAME}_bl.bin"
    if command -v "${OBJCOPY}" >/dev/null 2>&1 && [[ -f "${APP_BIN}" && -f "${BL_BIN}" ]]; then
        # App load address (e.g. 0x08010000) from the ELF's first ihex record; the
        # bootloader always loads at 0x08000000. Write to a temp file rather than
        # piping objcopy to /dev/stdout|sed -- in a redirected/background context
        # that pipe can leave objcopy blocked (zombie), stalling packaging.
        APP_HEX_TMP="$(mktemp)"
        "${OBJCOPY}" -O ihex "${APP_ELF}" "${APP_HEX_TMP}" 2>/dev/null || true
        APP_BASE="$(sed -n '1{s/^:02000004\([0-9A-Fa-f]\{4\}\).*/0x\10000/p;q}' "${APP_HEX_TMP}")"
        rm -f "${APP_HEX_TMP}"
        APP_BASE="${APP_BASE:-0x08010000}"
        "${OBJCOPY}" -I binary -O ihex --change-addresses "${APP_BASE}" "${APP_BIN}" "${RELEASE_DIR}/${OUT_BASE}.hex"
        "${OBJCOPY}" -I binary -O ihex --change-addresses 0x08000000   "${BL_BIN}"  "${RELEASE_DIR}/${BOARD_NAME}_bl.hex"
        # The combined bootloader+app hex is best produced natively by waf
        # (bin/AP_Periph_with_bl.hex via Tools/scripts/make_intel_hex.py), which
        # needs the python 'intelhex' module:  pip install intelhex .  When that
        # native hex exists it is copied above; only synthesize a board-named
        # combined hex here as a FALLBACK when intelhex was missing at build time.
        if [[ ! -f "${RELEASE_DIR}/${OUT_BASE}_with_bl.hex" ]]; then
            { head -n -1 "${RELEASE_DIR}/${BOARD_NAME}_bl.hex"; cat "${RELEASE_DIR}/${OUT_BASE}.hex"; } \
                > "${RELEASE_DIR}/${OUT_BASE}_with_bl.hex"
        fi
    else
        echo "warning: ${OBJCOPY} or .bin missing; skipping AP_Periph hex generation" >&2
    fi
fi

# One manifest PER VEHICLE. A board that ships several vehicles off one board_id
# (AF-H7E: 6202 = Copter + Plane) writes into the same release dir, so a single
# manifest.txt was last-writer-wins: it claimed "vehicle=plane" while listing the
# arducopter files sitting next to it. Each vehicle now owns its own manifest and
# lists only its own artifacts; release.sh reads whichever ones are present.
MANIFEST_PATH="${RELEASE_DIR}/manifest_${OUT_BASE}.txt"   # release.sh looks for manifest_<apj basename>.txt
{
    echo "board=${BOARD_NAME}"
    echo "vehicle=${VEHICLE}"
    echo "vehicle_bin=${VEHICLE_BIN}"
    echo "out_base=${OUT_BASE}"
    if [[ -n "${VEHICLE_LABEL:-}" ]]; then echo "vehicle_label=${VEHICLE_LABEL}"; fi
    echo "source_tree=firmware/ardupilot"
    echo "board_config=boards/${BOARD_NAME}/ardupilot"
    echo "ap_commit=$(git -C "${AP_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    if [[ -n "${NOVAX_VERSION:-}" ]]; then echo "novax_version=${NOVAX_VERSION}"; fi
    echo "generated_at=$(date -Iseconds)"
    echo "files:"
    find "${RELEASE_DIR}" -maxdepth 1 -type f \
         \( -name "${OUT_BASE}.*" -o -name "${OUT_BASE}_*" \
            -o -name "${BOARD_NAME}_bl.*" \) -printf '  %f\n' | sort
} > "${MANIFEST_PATH}"

# The shared manifest.txt becomes a lie as soon as a second vehicle lands; drop it.
rm -f "${RELEASE_DIR}/manifest.txt"

echo "Packaged firmware in ${RELEASE_DIR}"
