# AP-RTK X20D — ArduPilot AP_Periph Board Config

DroneCAN RTK GNSS + dual-antenna heading + compass peripheral, built on the
novaX AP-RTK dual carrier board with the Unicore UM982 replaced by a
**u-blox ZED-X20D**.

> **Status: work in progress — do not build for release yet.**
> ArduPilot has no ZED-X20D driver. This config builds a position-only
> peripheral; heading does not work until the driver work in
> [`../PORTING.md`](../PORTING.md) is done. Read that first.

Key hardware mapping:

- MCU: `STM32F412Rx`
- GNSS: u-blox ZED-X20D on `USART2` (UBX, single module, two antennas)
- Compass: `RM3100` on `I2C3` at `0x20`
- CAN: `CAN1` (DroneCAN node)
- Firmware: **AP_Periph** (peripheral firmware, not a vehicle firmware)
- DroneCAN node name: `AP-RTK X20D` (`CAN_APP_NODE_NAME`)
- Board ID: `6205` (new novaX id — see below)

## Why the ZED-X20D

The point of this board is to match what AP-RTK dual already does — heading
from two antennas — without the Unicore receiver, and to do it on one chip.

| | AP-RTK dual (UM982) | this board (ZED-X20D) | u-blox ZED-F9P × 2 |
|---|---|---|---|
| Receivers | 1 | 1 | 2 (master + slave) |
| Antennas | 2 | 2 | 2 |
| Bands | L1/L2 | **L1/L2/L5/L6 + L-band** | L1/L2 |
| ArduPilot | `GPS_TYPE 25`, native | **driver port required** | `GPS_TYPE 17/18`, mature |

A two-chip F9P design was considered and rejected: it doubles board area,
power and BOM to land at UM982-equivalent L1/L2 performance, so it is a step
backwards from the board it is meant to succeed.

## Differences vs AP-RTK dual

Everything except the receiver is carried over unchanged — MCU, compass, CAN,
power tree, LED and pinout all come straight from AP-RTK dual.

- **GNSS backend**: NMEA/Unicore (`AP_GPS_NMEA_UNICORE_ENABLED`,
  `NMEA_UNICORE_SETUP`, `GPS_TYPE 25`) removed; u-blox UBX backend
  (`AP_GPS_UBLOX_ENABLED`) in its place. `HAL_GPS1_TYPE_DEFAULT` is `2`
  (plain u-blox) as an interim — position only, no yaw.
- **`APJ_BOARD_ID` → 6205** (AP-RTK dual keeps CUAV's 1085). A bootloader only
  boots an app whose board id matches, and AP-RTK dual's inherited 1085 existed
  to allow OTA onto boards that already carried a CUAV bootloader. This is new
  hardware with no such installed base, so that argument does not apply — and
  since the two products share a connector and carrier board but not a
  receiver, a shared id would let Mission Planner push UM982 firmware onto an
  X20D board, which would boot and then never get a fix. 6205 is verified free
  both upstream (no 62xx in `Tools/AP_Bootloader/board_types.txt`) and in this
  repo, and sits in the same 62xx series as the novaX flight controllers.
- **`GPS_MOVING_BASELINE` kept enabled** — not because two receivers are
  involved, but because reusing the existing `UBX-NAV-RELPOSNED` plumbing is
  the cheapest candidate path to heading. See `PORTING.md`.

## Open hardware items

- **Compass axis reversal is inherited, not measured.** AP-RTK dual needed
  `AP_RM3100_REVERSAL_MASK 4` because its RM3100 Z axis reads inverted. That
  define is carried over on the assumption the part placement is unchanged.
  Re-run the four-heading check (60 / 150 / 230 / 300°) on the first article
  and drop or adjust the mask if it no longer applies.
- **USART2 baud / DMA** — the X20D runs all-band at up to 25 Hz, a heavier
  stream than the UM982 carried. Confirm the required baud and whether the port
  needs DMA against the X20D integration manual before freezing the PCB.
- **Power and RF budget** — supply rails, current draw and the second antenna
  path were sized for the UM982. Re-check against the X20D datasheet.

Build:

```bash
scripts/build_ap.sh AP-RTK_X20D AP_Periph
```

Flash (this board has no USB DFU):

| File | When |
|------|------|
| `AP-RTK_X20D_with_bl.hex` | **First flash** — combined bootloader + app, one-shot via ST-Link / SWD (PA13/PA14), e.g. STM32CubeProgrammer |
| `AP_Periph.apj` / `AP_Periph.bin` | Update over DroneCAN (Mission Planner SLCAN → Update firmware) once the bootloader is present |
| `AP-RTK_X20D_bl.bin` + `AP_Periph.bin` | Alternative two-step SWD flash: bootloader at `0x08000000`, app at `0x08010000` |

Layout:

- `hwdef.dat`: AP_Periph hardware definition
- `hwdef-bl.dat`: bootloader hardware definition
