# AF-F4 nano v2 ArduPilot Board Config

This directory is the single source of truth for the `AF-F4_nano_v2` ArduPilot board definition.

Key hardware mapping:

- MCU: `STM32F405xx`, 8 MHz external oscillator, 1024 KB flash
- Board ID: `6204` (its own id — the AF-F4 nano family's `6203` firmware is not compatible)
- IMU: `ICM-42688-P` on `SPI1`, CS `PC2`
- Barometer: `DPS368` on `I2C1` at `0x76`
- GPS: external module carrying `MAX-M10S`, connected to `USART1` (not onboard)
- Compass: `QMC5883P` on `I2C1` (external, on the GPS module)
- SD card: `SPI3`, CS `PC1`
- Current firmware: 5 configured motor outputs (`PC6`, `PC7`, `PC8`, `PC9`, `PA15`). `PA8` is not assigned a PWM output in the current definition or the v1.0.11 release tag; do not advertise six working firmware outputs.
- Status LEDs: blue `PB9`, green `PA14`
- USB detect: `PB12` (VBUS)
- No onboard OSD chip

Notes:

- The green LED shares `PA14` with `SWCLK`, so the application gives up SWD to drive it. The
  bootloader still maps `PA14` as `SWCLK` (see `hwdef-bl.dat`), so SWD recovery works while the
  board is in the bootloader; soft DFU and BOOT0 DFU are the other reflash paths.
- `BATT_AMP_PERVLT` defaults to `17.0` for the 184 A sensor and is expected to be calibrated
  per unit.

Layout:

- `hwdef.dat`: main flight-controller hardware definition
- `hwdef-bl.dat`: bootloader hardware definition
- `defaults.parm`: board-specific default parameters (GPS type, ESC protocol, compass)

Both `hwdef.dat` and `hwdef-bl.dat` set `ENABLE_DFU_BOOT 1`. The app's `Util::boot_to_dfu()`
stores a flag in persistent data and reboots; the bootloader's `__entry_hook()` reads it and
jumps to the STM32F4 system memory at `0x1FFF0000`, which enumerates as USB DFU. The hook is
compiled only when the bootloader is built with `ENABLE_DFU_BOOT`, so both files must set it.

Build flow:

1. Run `scripts/sync_ap_board.sh AF-F4_nano_v2`
2. Run `scripts/build_ap.sh AF-F4_nano_v2 copter`
3. Collect release artifacts from `releases/AF-F4_nano_v2/ardupilot/`
