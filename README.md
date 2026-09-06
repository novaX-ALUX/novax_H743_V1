# novaX FC

[한국어](README_ko.md) | [日本語](README_ja.md)

Canonical source: [novaX-ALUX/fc](https://github.com/novaX-ALUX/fc). The current tree contains FC configurations, the AD-ME1 rebrand variant, and three GNSS configurations awaiting extraction. **GNSS peripherals are not FCs; the GNSS/shared-source split is not complete.**

## Current board configurations

Derived from actual hardware definitions, bootloader IDs, board VERSION files and configuration paths. **A configuration is not proof of hardware qualification or a published release.** Build MCU target means the software backend: AF-F7 mini declares STM32F765IIK6 with an STM32F767xx backend; AF-H7E declares STM32H753IIK6 with an STM32H743xx backend. Do not interpret backend names as replacement-part specifications.

<!-- board-inventory:start -->
| Board directory | Scope | Build MCU target | Board ID | Source version | Configuration present |
|---|---|---|---|---|---|
| [AD-ME1](boards/AD-ME1/ardupilot/) | Rebrand variant | `STM32F405xx` | 6203 | 0.1.0 | ArduPilot |
| [AF-F4_nano](boards/AF-F4_nano/ardupilot/) | FC | `STM32F405xx` | 6203 | 1.2.3 | ArduPilot + Betaflight config |
| [AF-F4_nano_v2](boards/AF-F4_nano_v2/ardupilot/) | FC | `STM32F405xx` | 6204 | 1.0.11 | ArduPilot |
| [AF-F4_T10_nano](boards/AF-F4_T10_nano/ardupilot/) | FC | `STM32F405xx` | 6203 | 1.3.4 | ArduPilot |
| [AF-F7_mini](boards/AF-F7_mini/ardupilot/) | FC | `STM32F767xx` | 6201 | 1.3.0 | ArduPilot |
| [AF-H7_nano](boards/AF-H7_nano/ardupilot/) | FC | `STM32H743xx` | 6200 | 1.2.3 | ArduPilot + Betaflight config |
| [AF-H7E](boards/AF-H7E/ardupilot/) | FC | `STM32H743xx` | 6202 | 1.3.0 | ArduPilot |
| [AP-RTK_dual](boards/AP-RTK_dual/ardupilot/) | GNSS (transitional) | `STM32F412Rx` | 1085 | 0.1.0 | AP_Periph |
| [AP-RTK_G5H](boards/AP-RTK_G5H/ardupilot/) | GNSS (transitional) | `STM32F412Rx` | 6206 | 0.1.0 | AP_Periph |
| [AP-RTK_X20D](boards/AP-RTK_X20D/ardupilot/) | GNSS (transitional) | `STM32F412Rx` | 6205 | 0.1.0 | AP_Periph |
<!-- board-inventory:end -->

## Actual repository structure

This is the current tree, not the proposed future layout. Local product hardware/docs directories may be untracked and are not guaranteed to be present in a new public clone. GitHub Releases is a remote service, not a source directory.

```text
fc/
├─ boards/
│  ├─ AD-ME1/
│  ├─ AF-F4_nano/
│  ├─ AF-F4_nano_v2/
│  ├─ AF-F4_T10_nano/
│  ├─ AF-F7_mini/
│  ├─ AF-H7_nano/
│  ├─ AF-H7E/
│  ├─ AP-RTK_dual/
│  ├─ AP-RTK_G5H/
│  └─ AP-RTK_X20D/
├─ firmware/
│  ├─ ardupilot/     # pinned Git submodule
│  └─ betaflight/    # pinned Git submodule
├─ patches/ardupilot/
├─ scripts/          # sync, build, package, release, validation
├─ VERSION           # fallback; boards/<board>/VERSION takes priority
├─ VERSIONING.md
├─ build/            # generated, ignored
└─ releases/         # generated, ignored
```

## Build and independent versions

Use Linux/WSL with the dependencies required by the pinned upstream sources. Apply reviewed novaX patches before building and resolve any warning before release. Do not update or overwrite a dirty existing submodule. Betaflight configs exist only for AF-F4_nano and AF-H7_nano; this does not certify a new successful build.

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/novaX-ALUX/fc.git
cd fc
./scripts/apply_ap_patches.sh
./scripts/build_ap.sh AF-F4_nano copter
# AP-RTK_* targets use AP_Periph, not copter.
```

Version priority: `NOVAX_VERSION` → `boards/<board>/VERSION` → root `VERSION` → `dev`. FC strings include the vehicle, e.g. `novaX Copter v1.3.0`; AP_Periph output filenames carry the board version. Products do **not** share one common version. See [VERSIONING.md](VERSIONING.md).

## Release and update limits

The 2026-09-06 release inventory verified existing board-scoped releases for six AF-* boards, AP-RTK dual and AP-RTK G5H. No board-scoped release was verified for AD-ME1 or AP-RTK X20D. A VERSION file is not shipment approval.

`release.sh` may replace existing release assets. Use an unreleased board-scoped tag only after approval and build verification. DRY_RUN does not publish, but signed boards still require a local signer/key. Actual publishing requires the Git-ignored GITHUB_ACCESS_TOKEN. AF-F4_nano_v2 signatures must not be bypassed; use the workspace catalog signer or an explicit AFF4T10_FWSIG path.

```bash
# Set BOARD and NEW_TAG only for the reviewed, built, unreleased product.
DRY_RUN=1 ./scripts/release.sh "${NEW_TAG:?set unreleased board-scoped tag}" "${BOARD:?set board directory name}"
```

Use matching product/vehicle files. AD-ME1, AF-F4_nano and AF-F4_T10_nano share board ID 6203, so ID matching alone does not prove feature/pin compatibility. AF-F4_nano_v2 uses 6204. FC .apj files use the USB bootloader/serial updater; matching _with_bl.hex files use board-specific DFU/SWD recovery. Do not assume buttonless DFU on every board.

AP-RTK dual: DroneCAN updates and SWD MCU recovery; receiver USB is not MCU DFU. AP-RTK G5H: DroneCAN, or board-specific MCU USB bootloader/DFU/SWD. AP-RTK X20D: development target, not a verified public release. The catalog [Web Updater](https://novax-alux.github.io/parts-catalog/update/) covers the listed FC files, not all peripherals.

## Documentation check

```bash
python3 scripts/validate_docs.py
```

Hardware design files are proprietary to novaX-ALUX. Firmware definitions follow their respective upstream licenses (GPLv3).
