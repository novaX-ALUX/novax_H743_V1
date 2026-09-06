# AF-F4_T10_nano (ArduPilot)

CADDX-gimbal variant of [AF-F4_nano](../../AF-F4_nano/ardupilot/README.md).

- **Hardware:** identical to AF-F4_nano (SpeedyBee F405 V4 base, STM32F405, SPL06 baro, MAX-M10S GPS, QMC5883P compass).
- **Board ID:** `6203` — same as AF-F4_nano, so an existing AF-F4_nano board accepts this firmware over the normal `.apj` updater (no DFU required).
- **Feature set:** mirrors the custom.ardupilot.org *Selected Features* used for the speedybeef4v4 build, applied via [`AF-F4_T10_features.inc`](AF-F4_T10_features.inc), **plus the CADDX gimbal mount**:
  - `HAL_MOUNT_ENABLED 1` (Camera Mounts)
  - `HAL_MOUNT_CADDX_ENABLED 1` (CADDX gimbal, `MNT_TYPE = 13`)
  - all other gimbal backends OFF.

## Using the gimbal

1. `MNT1_TYPE = 13` (CADDX)
2. Wire the gimbal to a suitable spare UART (e.g. SERIAL6) and set that port's `SERIALx_PROTOCOL = 8` (Gimbal). This is the protocol selected by `AP_Mount_Backend_Serial`, which the CADDX backend inherits. Confirm baud rate and wiring for the actual gimbal before use.

## Build

```
export PATH="$HOME/arm-gcc/gcc-arm-none-eabi-10-2020-q4-major/bin:$PATH"   # official gcc 10.2 required
./scripts/build_ap.sh AF-F4_T10_nano copter
```

`AF-F4_T10_features.inc` is auto-generated from `build.log` (custom-build Selected Features) + the CADDX gimbal.
