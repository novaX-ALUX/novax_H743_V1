#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ap_env.sh"
exec bash "${NOVAX_AP_ROOT}/Tools/novax/apply_patches.sh" "$@"
