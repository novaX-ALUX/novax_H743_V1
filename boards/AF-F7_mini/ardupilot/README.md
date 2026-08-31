# AF-F7 mini ArduPilot Board Config

Board definition for the AF-F7 mini flight controller — an autopilot-class
board that drives all PWM outputs directly (no IO co-processor).

Key hardware mapping:

- MCU: `STM32F765IIK6` (216MHz, 2MB Flash, UFBGA), 16MHz crystal
- IMU: `ICM-20689` + `ICM-20602` + `BMI055` (gyro/acc), all on `SPI1`
- Barometer: `MS5611` on `SPI4`
- Compass: `IST8310` on `I2C` (internal) + external probe
- FRAM: on `SPI2` (parameter storage)
- CAN: `FDCAN1` + `FDCAN2`
- SD Card: `SDMMC1` 4-bit
- RC input: dedicated RCIN pin `PI5` (all protocols)
- Motor Outputs: 11 (8x FMU_CH + 3x on TIM2)
- Board ID: `6201` (novaX-ALUX reserved range 6200–6209)

Pin mapping was derived from the board netlist (`docs/X5_Autopilot.NET`) and
verified against the STM32F765 UFBGA ballout.

Layout:

- `hwdef.dat`: main flight-controller hardware definition
- `hwdef-bl.dat`: bootloader hardware definition
- `defaults.parm`: board-specific default parameters (frame, battery, GPS, CAN)

Build:

```bash
scripts/build_ap.sh AF-F7_mini copter
scripts/build_ap.sh AF-F7_mini plane
```

Both vehicles share board id `6201`, so the image itself is the only thing that
says which one is running. The build stamps the vehicle into the GCS banner
(`novaX Copter v1.3.0` / `novaX Plane v1.3.0`) and the release assets carry a
`-Copter` / `-Plane` suffix.

Buttonless software DFU is supported (`ENABLE_DFU_BOOT 1` in both hwdefs,
board id 6201, unsigned). Note the F7 rule: the ROM jump lives in the
BOOTLOADER (`board.c __early_init`), because F4/F7 have no `BOOT_ADD0` option
byte and this tree's ChibiOS crt0 never calls the app-side `__entry_hook`.
**A `.apj` alone does not enable it — flash `_with_bl.hex` once.** (AF-H7E is
the opposite: it commits `BOOT_ADD0`, so the app alone is enough.)

Verify before flight:

- IMU and compass **rotations** are provisional — confirm against the physical
  chip placement on the bench.
- Battery voltage/current scaling uses standard power-module values
  (`18.0` / `24.0`) — confirm against the shipped power module.
