# AF-H7 nano ArduPilot Board Config

Board definition for the AF-H7 nano flight controller.

Key hardware mapping:

- MCU: `STM32H743VIH6` (480MHz, 2MB Flash, TFBGA-100)
- IMU: Dual `ICM-42688-P` on `SPI1` + `SPI4`
- Barometer: the schematic labels U22 as DPS310/DPS368; firmware probes the DPS310 and SPL06 backends on `I2C2` at `0x76`. These are alternative backend probes, not two installed barometers. Confirm the fitted part on the board revision.
- Compass: `IST8310` on `I2C2` at `0x0E` (internal)
- OSD: `AT7456E` on `SPI2`
- CAN: `FDCAN1` with `TJA1051TK/3`
- SD Card: `SDMMC1` 4-bit
- Motor Outputs: 10 (M1-M4 bidirectional DShot)

Layout:

- `hwdef.dat`: main flight-controller hardware definition
- `hwdef-bl.dat`: bootloader hardware definition
- `defaults.parm`: board-specific default parameters (battery, GPS, ELRS, DJI O3, CAN)

Build:

```bash
scripts/build_ap.sh AF-H7_nano copter
```
