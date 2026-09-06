# Each product checkout uses one sibling shared source; no implicit clone/pull.
export NOVAX_PRODUCT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NOVAX_AP_ROOT="${NOVAX_AP_ROOT:-${NOVAX_PRODUCT_ROOT}/../_shared/ardupilot}"
if [[ ! -f "${NOVAX_AP_ROOT}/Tools/novax/paths.sh" ]]; then
    echo "Shared ArduPilot missing. Follow README shared-source setup or set NOVAX_AP_ROOT." >&2
    exit 1
fi
