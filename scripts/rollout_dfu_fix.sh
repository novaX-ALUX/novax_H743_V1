#!/usr/bin/env bash
# Roll out the software-DFU bootloader fix to all FC boards.
# Forces a clean bootloader + app rebuild per board so the patched board.c/Util.cpp and the
# regenerated (DFU-enabled) bootloader are actually compiled in. Each board's
# version is read from boards/<board>/VERSION by build_ap.sh (per-board, so
# bumping one board never bumps the others).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/arm-gcc/gcc-arm-none-eabi-10-2020-q4-major/bin:$PATH"
cd "$ROOT"
source "${ROOT}/scripts/ap_env.sh"

BOARDS=(AF-F4_nano AF-F7_mini AF-H7_nano AF-H7E AF-F4_T10_nano)
FAIL=()
for b in "${BOARDS[@]}"; do
  echo "==================== $b  (v$(cat "boards/$b/VERSION" 2>/dev/null || echo dev)) ===================="
  scripts/sync_ap_board.sh "$b" || { FAIL+=("$b:sync"); continue; }
  build_dir="$(realpath -m "${NOVAX_AP_ROOT}/build/${b}")"
  [[ "$build_dir" == "$(realpath "${NOVAX_AP_ROOT}")/build/${b}" ]] || exit 1
  rm -rf -- "$build_dir"
  ( cd "${NOVAX_AP_ROOT}" && python3 Tools/scripts/build_bootloaders.py "$b" ) || { FAIL+=("$b:bl"); continue; }
  scripts/build_ap.sh "$b" copter || { FAIL+=("$b:app"); continue; }  # version from boards/$b/VERSION
  echo "---- $b done ----"
done
echo "==================== SUMMARY ===================="
[ ${#FAIL[@]} -eq 0 ] && echo "ALL 5 BOARDS OK" || echo "FAILURES: ${FAIL[*]}"
