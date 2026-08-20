#!/usr/bin/env bash
set -euo pipefail

# Publish firmware to a GitHub Release as INDIVIDUAL files (NO zip).
# Release notes follow the same layout as the global v0.1.x releases (Jarvis):
#   ## Firmware Release <tag>
#   | Board | Platform | Commit |   (one row per board/platform)
#   ### Download                     (per-board file list, purposes)
# but the assets are the individual files instead of a per-board zip:
#   <prefix>.apj           - OTA update via Mission Planner
#   <prefix>.bin           - app binary (OTA)
#   <prefix>_with_bl.hex   - first flash via STLink/DFU (bootloader + app)
#   <prefix>-betaflight.hex- flash via Betaflight Configurator (FC boards)
# <prefix> is the tag for a board-scoped tag (e.g. AF-F4_nano-v0.1.4),
# otherwise "<board>-<tag>" so files stay distinguishable.
#
# Uses the GitHub REST API with GITHUB_ACCESS_TOKEN from .env (no `gh`, no `zip`).
#
# Usage:
#   scripts/release.sh <tag> [board ...]
#     scripts/release.sh AF-F4_nano-v0.1.4 AF-F4_nano   # one board
#     scripts/release.sh v0.1.5                          # all boards in releases/
#   DRY_RUN=1 scripts/release.sh <tag> [board ...]       # show plan, touch nothing
#
# Build artifacts first (scripts/build_ap.sh / build_bf.sh).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:?Usage: release.sh <tag> [board ...]}"
shift || true

# A version tag must match the VERSION the firmware was built from, so the
# release label matches what GCS reports. Each hardware is versioned per-board:
#   - Board-scoped tag "<board>-vX.Y.Z" is checked against boards/<board>/VERSION
#   - Global tag       "vX.Y.Z"         is checked against the repo-root VERSION
# Override with ALLOW_VERSION_MISMATCH=1 for a deliberate re-tag.
_check_version() {  # <label> <tag_version> <file_version>
    if [[ "${2}" != "${3}" && "${ALLOW_VERSION_MISMATCH:-0}" != "1" ]]; then
        echo "Error: tag '${TAG}' (v${2}) does not match ${1} (${3})." >&2
        echo "       The firmware was built with novaX v${3}; releasing it as" >&2
        echo "       '${TAG}' would mislabel it. Fix the VERSION file (and rebuild) or the tag." >&2
        echo "       Override with ALLOW_VERSION_MISMATCH=1 if this is intentional." >&2
        exit 1
    fi
}
if [[ "${TAG}" =~ ^(.+)-v?([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    _board="${BASH_REMATCH[1]}"; _tagver="${BASH_REMATCH[2]}"
    _bvf="${ROOT_DIR}/boards/${_board}/VERSION"
    [[ -f "${_bvf}" ]] && _check_version "boards/${_board}/VERSION" "${_tagver}" "$(tr -d '[:space:]' < "${_bvf}")"
elif [[ "${TAG}" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)$ && -f "${ROOT_DIR}/VERSION" ]]; then
    _check_version "VERSION file" "${BASH_REMATCH[1]}" "$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
fi

cd "${ROOT_DIR}"
TAG="${TAG}" BOARDS="${*}" DRY_RUN="${DRY_RUN:-}" python3 - <<'PYEOF'
import json, os, sys, urllib.request, urllib.error

REPO   = 'novaX-ALUX/flight_controller'
TAG    = os.environ['TAG']
BOARDS = os.environ.get('BOARDS', '').split()
DRY    = bool(os.environ.get('DRY_RUN'))
REL    = 'releases'

PURPOSE = {
    'apj':          'OTA update via Mission Planner',
    'bin':          'app binary (OTA)',
    '_with_bl.hex': 'first flash via STLink/DFU (bootloader + app)',
    'betaflight':   'flash via Betaflight Configurator',
}

# waf target -> human label used in release asset names. Only applied when a
# board ships more than one vehicle (see the loop below).
VEHICLE_LABEL = {
    'arducopter': 'Copter', 'arduplane': 'Plane', 'ardurover': 'Rover',
    'ardusub': 'Sub', 'antennatracker': 'Tracker', 'blimp': 'Blimp',
    'AP_Periph': 'Periph',
}

def get_token():
    for line in open('.env'):
        if line.startswith('GITHUB_ACCESS_TOKEN='):
            return line.split('=', 1)[1].strip().strip('"').strip("'")
    sys.exit('GITHUB_ACCESS_TOKEN not found in .env')

def api(url, data=None, method='GET', ctype='application/json'):
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header('Authorization', 'token ' + TOKEN)
    req.add_header('Accept', 'application/vnd.github+json')
    if data is not None:
        req.add_header('Content-Type', ctype)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, {}

def is_peripheral(board):
    # DroneCAN/AP_Periph peripherals (e.g. AP-RTK_dual) are released on their own
    # version track, so they are excluded from auto-discovery under a shared FC tag.
    meta = os.path.join('boards', board, 'metadata.yaml')
    try:
        for line in open(meta):
            s = line.strip().lower()
            if s.startswith('firmware_type:') and 'ap_periph' in s:
                return True
    except OSError:
        pass
    return False

if not BOARDS:
    BOARDS = sorted(d for d in os.listdir(REL) if os.path.isdir(os.path.join(REL, d)))
    for b in [b for b in BOARDS if is_peripheral(b)]:
        print('note: skipping peripheral %s (own version track, not %s)' % (b, TAG), file=sys.stderr)
    BOARDS = [b for b in BOARDS if not is_peripheral(b)]
if not BOARDS:
    sys.exit('No release artifacts in releases/. Build first.')

assets      = []   # (asset_name, src_path, key)
board_rows  = []   # (board, platform, commit) for the top table
dl_sections = []   # (board, [(asset_name, purpose), ...]) for the Download section

for board in BOARDS:
    bdir = os.path.join(REL, board)
    if not os.path.isdir(bdir):
        print('warn: no releases for %s, skipping' % board, file=sys.stderr)
        continue
    prefix = TAG if TAG.startswith(board) else ('%s-%s' % (board, TAG))
    files_for_board = []

    ap = os.path.join(bdir, 'ardupilot')
    if os.path.isdir(ap):
        files = sorted(os.listdir(ap))
        # A board can ship SEVERAL vehicles off one board_id (AF-H7E: 6202 =
        # Copter + Plane). Releasing next(...apj) picked whichever sorted first
        # and published a single unlabelled asset -- the other vehicle silently
        # never shipped, and nothing in the name said which one you downloaded.
        # Publish every vehicle found; add a -<Vehicle> suffix ONLY when the board
        # actually has more than one, so single-vehicle boards keep the exact
        # asset names the parts-catalog already links to.
        apjs = [f for f in files if f.endswith('.apj')]
        vehicles = [(a[:-4], VEHICLE_LABEL.get(a[:-4], a[:-4])) for a in apjs]
        multi_vehicle = len(vehicles) > 1
        for vbin, vlabel in vehicles:
            had = False   # per-vehicle: a row is added only if THIS vehicle shipped
            sfx = ('-' + vlabel) if multi_vehicle else ''
            plan = [('apj',          vbin + '.apj',          prefix + sfx + '.apj'),
                    ('bin',          vbin + '.bin',          prefix + sfx + '.bin'),
                    ('_with_bl.hex', vbin + '_with_bl.hex',  prefix + sfx + '_with_bl.hex')]
            for key, fname, aname in plan:
                if os.path.isfile(os.path.join(ap, fname)):
                    assets.append((aname, os.path.join(ap, fname), key))
                    files_for_board.append((aname, PURPOSE[key]))
                    had = True
            if had:
                commit = '-'
                # per-vehicle manifest (manifest_arducopter.txt); fall back to the
                # legacy shared manifest.txt for release dirs built before the split.
                for man in (os.path.join(ap, 'manifest_%s.txt' % vbin),
                            os.path.join(ap, 'manifest.txt')):
                    if os.path.isfile(man):
                        for l in open(man):
                            if l.startswith('ap_commit='):
                                commit = l.split('=', 1)[1].strip()
                        break
                board_rows.append((board, 'ardupilot ' + vlabel if multi_vehicle
                                          else 'ardupilot', commit))

    bf = os.path.join(bdir, 'betaflight')
    if os.path.isdir(bf):
        hexf = next((f for f in os.listdir(bf) if f.endswith('.hex')), None)
        if hexf:
            aname = prefix + '-betaflight.hex'
            assets.append((aname, os.path.join(bf, hexf), 'betaflight'))
            files_for_board.append((aname, PURPOSE['betaflight']))
            board_rows.append((board, 'betaflight', '-'))

    if files_for_board:
        dl_sections.append((board, files_for_board))

if not assets:
    sys.exit('No individual files found to upload (build first).')

# --- Build release notes in the v0.1.x (Jarvis) layout ---
notes = ['## Firmware Release %s' % TAG, '',
         '| Board | Platform | Commit |', '|-------|----------|--------|']
for b, p, c in board_rows:
    notes.append('| %s | %s | `%s` |' % (b, p, c))
notes += ['', '### Download', '']
multi = len(dl_sections) > 1
for board, files in dl_sections:
    if multi:
        notes += ['**%s**' % board, '']
    notes += ['| File | Purpose |', '|------|---------|']
    for aname, purpose in files:
        notes.append('| `%s` | %s |' % (aname, purpose))
    notes.append('')
notes_txt = '\n'.join(notes).rstrip() + '\n'

print('Release tag : %s' % TAG)
print('Assets (%d):' % len(assets))
for name, path, _ in assets:
    print('  %-34s <- %s (%d B)' % (name, path, os.path.getsize(path)))

if DRY:
    print('\n[DRY_RUN] nothing published. Notes preview:\n')
    print(notes_txt)
    sys.exit(0)

TOKEN = get_token()
st, rel = api('https://api.github.com/repos/%s/releases/tags/%s' % (REPO, TAG))
if st == 200:
    rid = rel['id']
    api('https://api.github.com/repos/%s/releases/%d' % (REPO, rid),
        data=json.dumps({'name': TAG, 'body': notes_txt}).encode(), method='PATCH')
    existing = {a['name']: a['id'] for a in rel.get('assets', [])}
    print('reusing release:', rel['html_url'])
else:
    payload = json.dumps({'tag_name': TAG, 'target_commitish': 'main', 'name': TAG,
                          'body': notes_txt, 'draft': False, 'prerelease': False}).encode()
    st, rel = api('https://api.github.com/repos/%s/releases' % REPO, data=payload, method='POST')
    if st not in (200, 201):
        sys.exit('create release FAILED %s %s' % (st, rel.get('message')))
    rid, existing = rel['id'], {}
    print('created release:', rel['html_url'])

for name, path, _ in assets:
    if name in existing:
        api('https://api.github.com/repos/%s/releases/assets/%d' % (REPO, existing[name]), method='DELETE')
    data = open(path, 'rb').read()
    st, r = api('https://uploads.github.com/repos/%s/releases/%d/assets?name=%s' % (REPO, rid, name),
                data=data, method='POST', ctype='application/octet-stream')
    print(('  uploaded ' if st in (200, 201) else '  FAILED %s ' % st) + name)

print('DONE:', rel['html_url'])
PYEOF
