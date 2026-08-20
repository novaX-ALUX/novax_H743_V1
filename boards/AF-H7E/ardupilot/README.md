# AF-H7E ArduPilot Board Config

Board definition for the AF-H7E flight controller — a modular autopilot with
triple-redundant IMUs, dual CAN and Ethernet.

Key hardware mapping:

- MCU: `STM32H753IIK6` (480MHz, 2MB Flash, UFBGA-201), 16MHz crystal
- Modules:
  - `V6X-FM`: FMU + `FM25V05` FRAM + `SE050` secure element + `ICP-20100` baro + `ICM-20649` IMU
  - `V6X-IMU`: `ICM-42688-P` + `BMI088` + `ICP-20100` baro + `RM3100` compass
  - `U6X-BASE`: `STM32F103` IO co-processor + `LAN8742` Ethernet + `LTC4417` power path + 2x `MCP2542` CAN
- IMU: `ICM-42688-P` + `BMI088` + `ICM-20649` (triple redundant)
- Barometer: 2x `ICP-20100`
- Compass: `RM3100`
- CAN: `FDCAN1` + `FDCAN2`
- Ethernet: `LAN8742` (100BASE-T)
- Board ID: `6202` (novaX-ALUX reserved range 6200–6209)

The V6X-FM compute module exposes raw MCU pins to the carrier over
board-to-board connectors, so pin functions are fixed by the module interface.
The board class is auto-detected at runtime — the I2C ID EEPROM must be
programmed to the matching board type.

Layout:

- `hwdef.dat`: main flight-controller hardware definition
- `hwdef-bl.dat`: bootloader hardware definition
- `defaults.parm`: board-specific default parameters (frame, INA2xx battery, dual CAN)

Build:

```bash
scripts/build_ap.sh AF-H7E copter
scripts/build_ap.sh AF-H7E plane
```

Both vehicles share board id `6202`, so the image itself is the only thing that
says which one you are running. The build stamps the vehicle into the GCS banner
(`novaX Copter v1.3.0` / `novaX Plane v1.3.0`) and the release assets carry a
`-Copter` / `-Plane` suffix.

Flashing notes:

- `arducopter_with_bl.hex` / `arduplane_with_bl.hex` — **first flash** (bootloader + app) via STM32 ROM
  DFU (BOOT0) or ST-Link/SWD. Required to install the novaX `6202` bootloader.
- `arducopter.apj` / `arduplane.apj` — OTA update once the `6202` bootloader is present.
- A bootloader built for a different board id only accepts a matching `.apj`;
  use DFU/SWD (or a forced upload) to switch a board between firmwares.

Verify before flight:

- IMU and compass **rotations** are provisional — confirm against the physical
  chip placement on the bench.
