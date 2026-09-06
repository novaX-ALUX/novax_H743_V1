# AF-F4_T10_nano (ArduPilot)

CADDX-gimbal configuration variant of [AF-F4_nano](../../AF-F4_nano/ardupilot/hwdef.dat).

- **Configuration:** STM32F405 and SPL06 barometer; MAX-M10S GNSS and QMC5883P compass are external peripherals, not onboard components.
- **Board ID:** `6203`, shared with AF-F4_nano and AD-ME1. An ID match alone does not prove pin/feature compatibility; use only the reviewed product-specific image.
- **Feature set:** mirrors the custom.ardupilot.org *Selected Features* used for the speedybeef4v4 build, applied via [`AF-F4_T10_features.inc`](AF-F4_T10_features.inc), **plus the CADDX gimbal mount**:
  - `HAL_MOUNT_ENABLED 1` (Camera Mounts)
  - `HAL_MOUNT_CADDX_ENABLED 1` (CADDX gimbal, `MNT_TYPE = 13`)
  - all other gimbal backends OFF.

## Using the gimbal

1. `MNT1_TYPE = 13` (CADDX)
2. Wire the gimbal to a suitable spare UART (e.g. SERIAL6) and set that port's `SERIALx_PROTOCOL = 8` (Gimbal). This is the protocol selected by `AP_Mount_Backend_Serial`, which the CADDX backend inherits. Confirm baud rate and wiring for the actual gimbal before use.

## Build

```
# Run from the FC repository root; ArduPilot uses GCC 10.2.1.
bash ../_shared/ardupilot/Tools/novax/install_toolchain.sh
bash scripts/build_ap.sh AF-F4_T10_nano copter
```

`AF-F4_T10_features.inc` is auto-generated from `build.log` (custom-build Selected Features) + the CADDX gimbal.
