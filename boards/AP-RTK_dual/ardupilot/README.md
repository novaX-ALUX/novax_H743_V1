# AP-RTK dual — ArduPilot AP_Periph Board Config

DroneCAN RTK GNSS + compass peripheral, based on the CUAV C-RTK2-HP design,
adapted for the novaX "AP-RTK dual" clone board.

Key hardware mapping:

- MCU: `STM32F412Rx`
- GNSS: moving-baseline capable receiver on `USART2` (DroneCAN GPS type 25, NMEA Unicore)
- Compass: `RM3100` on `I2C3` at `0x20`
- CAN: `CAN1` (DroneCAN node)
- Firmware: **AP_Periph** (peripheral firmware, not a vehicle firmware)
- DroneCAN node name: `AP-RTK dual` (`CAN_APP_NODE_NAME`)
- Board ID: `1085` (kept same as CUAV C-RTK2-HP — see note below)

Clone-specific changes vs CUAV C-RTK2-HP:

- `APJ_BOARD_ID` **kept at 1085** (same as CUAV). A bootloader only boots an
  app whose board id matches its own, so keeping 1085 lets this firmware be
  pushed over DroneCAN onto boards that already carry a CUAV 1085 bootloader —
  no per-board SWD re-flash. The flight controller binds the GPS/compass by
  message + node id, not by board id.
- DroneCAN node name → **"AP-RTK dual"**.
- **RM3100 X/Y axes are reversed** on this PCB, giving a constant 180° heading
  offset vs the CUAV board. Corrected in firmware with `ROTATION_YAW_90`
  (CUAV's `ROTATION_YAW_270` + 180°). Confirmed on hardware.

Layout:

- `hwdef.dat`: AP_Periph hardware definition
- `hwdef-bl.dat`: bootloader hardware definition

Build:

```bash
scripts/build_ap.sh AP-RTK_dual AP_Periph
```

Flash (this board has no USB DFU):

| File | When |
|------|------|
| `AP-RTK_dual_with_bl.hex` | **First flash** — combined bootloader + app, one-shot via ST-Link / SWD (PA13/PA14), e.g. STM32CubeProgrammer |
| `AP-RTK_dual-v<ver>.apj` / `.bin` (packaged name; waf emits `AP_Periph.*`) | Update over DroneCAN (Mission Planner SLCAN → Update firmware) once the bootloader is present |
| `AP-RTK_dual_bl.bin` + `AP-RTK_dual-v<ver>.bin` | Alternative two-step SWD flash: bootloader at `0x08000000`, app at `0x08010000` |

End users only flash the prebuilt firmware — the X/Y compass fix and the node
name are baked in; there are no parameters to set on the module.
