# AP-RTK G5H — ArduPilot AP_Periph Board Config

DroneCAN RTK GNSS + dual-antenna heading + compass peripheral: the novaX
AP-RTK dual carrier board with the Unicore UM982 replaced by a
**Septentrio mosaic-G5 P3H** (single module, two antennas, SBF protocol).
Receiver part number: Septentrio **410502** (mosaic-G5 P3H; 410501 is the
single-antenna P3, 410461 the P1 — HW manual v1.1.1 §3.1.1.1). "H" = heading
(second antenna input); dual-antenna mode tracks L1/L2/L5, no RAW output.

Hardware source: `41_Kicad/circuits/ap_rtk_g5h.py` (SKiDL netlist = truth) and
`41_Kicad/circuits/ap_rtk_g5h_v3.py` (wired schematic, verified pin-for-pin
against the netlist: 73/73 nets). Outputs in `41_Kicad/kicad/ap_rtk_g5h/`,
PDF copy in `39_gitNovaX/docs/rtk-gnss/AP-RTK_G5H/AP-RTK_G5H_schematic_v3.pdf`. Design
notes and the datasheet cross-check (mosaic-G5 HW manual pinout, TPS82130,
TJA1051, PNI RM3100): `41_Kicad/docs/AP-RTK_G5H/design.md` §4-1.

Two deviations from the AP-RTK dual carrier found by that cross-check:
the CAN transceiver is **TJA1051T/3 with VIO = 3.3 V** (the /1J on AP-RTK
dual needs TXD ≥ 0.7·VCC = 3.5 V, out of spec for a 3.3 V MCU), and the
RM3100 RES pins 2/20 are **tied to GND** as PNI requires.

Key hardware mapping:

- MCU: `STM32F412Rx`
- GNSS: mosaic-G5 P3H on `USART2` = receiver COM1 (`GPS_TYPE 26`, SBF dual antenna)
- Compass: `RM3100` on `I2C3` at `0x20`
- CAN: `CAN1` (DroneCAN node), node name `AP-RTK G5H`
- Board ID: `6206` (new novaX id; AP-RTK dual = 1085, AP-RTK X20D = 6205)
- USB-C: **STM32F412 OTG_FS** (schematic v3), `SERIAL0` = MAVLink GCS

## USB goes to the MCU, not the receiver (schematic v3)

AP-RTK dual routed its USB-C to the UM982 (through a CH340K). Here the USB-C
is wired to the F412 `PA11/PA12` and the mosaic-G5 USB pins are left open,
because everything the receiver needs works over its UART and the MCU gains
service access:

| Need | How, without receiver USB | Verified |
|---|---|---|
| Factory setup (`setFrontendMode, DualAnt`, `exeCopyConfigFile`) | RxTools on the 4-pin UART connector (receiver COM2) or the DroneCAN serial tunnel from the FC (`CAN_D1_UC_S1_NOD`, `S1_IDX -1` = this node's `GPS_PORT`) | AP 4.6.3 `Tools/AP_Periph/serial_tunnel.cpp`, `AP_DroneCAN_serial.cpp` |
| Receiver firmware upgrade (`.suf`) | RxUpgrade with *Select Serial Port* on COM2; raise the baud with `setCOMSettings` (COM ports up to 4 Mbit/s, `baud4000000`) | mosaic Reference Guide: upgrade mode accepts the SUF "from any of its connections"; HW manual 4.3 |
| MCU firmware | ST ROM DFU (`0483:df11`, BOOT0 key), ArduPilot bootloader over USB (`uploader.py` / Mission Planner), DroneCAN update, or soft-DFU (`param4=99` + magic 42,24,71, `ENABLE_DFU_BOOT`) | hwdef / hwdef-bl in this directory |

The Reference Guide notes that upgrading over a serial link is slow compared
with USB/Ethernet - at 3 Mbit/s a ~40 MB SUF takes a few minutes, which is fine
for a service operation.

## Why it works out of the box (verified in this tree, ArduPilot 4.6.3)

| Step | Where |
|---|---|
| `GPS_TYPE 26` instantiates the SBF driver | `libraries/AP_GPS/AP_GPS.cpp:727` |
| Driver configures the receiver: `scs` 230400 → `sso … +AttCovEuler+AuxAntPositions,msec100` → `sst` → `sga, MultiAntenna` | `AP_GPS_SBF.cpp:116-185` |
| Yaw from the `AuxAntPositions` block (RTK integer fix, main→aux vector) | `AP_GPS_SBF.cpp:610-625` |
| Periph broadcasts `ardupilot.gnss.Heading` when `gps.have_gps_yaw()` | `Tools/AP_Periph/gps.cpp:218-236` |
| FC consumes it as GPS yaw | `AP_GPS_DroneCAN.cpp:517-541` |
| RTCM from the GCS reaches the receiver (`RTCMStream` → `inject_data` → COM1) | `Tools/AP_Periph/gps.cpp:23`, `GPS_Backend.cpp:121` |

Flight-controller parameters are the same as for AP-RTK dual
(`CAN_P1_DRIVER 1`, `GPS1_TYPE 9`, `EK3_SRC1_YAW 3`, `AHRS_EKF_TYPE 3`).

### What happens on the UART at boot (no receiver config saved)

AP_Periph opens the GNSS UART at 230400 (`AP_SERIALMANAGER_GPS_BAUD`); the
receiver answers at its factory 115200, so the SBF driver's `SSSSSSSSSS`
probe gets no `COM1>` prompt, AP_GPS times out after 4 s and steps through
`_baudrates[]` (115200 -> handshake, `scs,COM1,baud230400` -> receiver
switches -> 4800/19200/38400/57600 -> 230400). Data starts ~20-30 s after
power-up, every power-up, because the driver never saves the receiver
configuration. Saving `baud230400` in the boot file (above) cuts this to
~2 s. Wiring is 3.3 V LVTTL straight to USART2, no level shifting.

## What is different from AP-RTK dual (read before shipping)

1. **Antenna offsets live on the peripheral, not the FC.** The SBF driver runs
   on this node and computes yaw with `calculate_moving_base_yaw()`, which
   needs `GPS1_MB_TYPE = 2` and `GPS1_MB_OFS_X/Y/Z` (auxiliary antenna
   position relative to the main antenna, body frame) *on this node*; with
   `MB_TYPE 0` it raises an internal error and reports no yaw, and a reported
   baseline that differs from the offset by more than 20 % is rejected
   (`GPS_Backend.cpp:327-350`). `defaults.parm` here embeds
   `GPS1_MB_TYPE 2` and a 0.50 m X baseline (the layout in the AP-RTK dual
   manual); a different separation is set with the Mission Planner DroneCAN
   parameter editor on the node. The FC-side `GPS1_MB_OFS_*` values are no
   longer used.
2. **One-time factory receiver setup** (the driver does not send these).
   Verified against the mosaic-G5 Firmware v1.0.1 Reference Guide (factory
   defaults are the underlined arguments): `setFrontendMode` default is
   **SingleAnt** (p.85) - a P3H out of the box ignores ANT_2 and reports no
   heading; `setGPIO1/2Mode` default is input (p.52) - the LEDs stay dark;
   COM ports default to 115200 8N1 (p.129); SBF output default `none` (p.145).
   Over the 4-pin UART (receiver COM2, RxTools) send once:

   ```
   setFrontendMode, DualAnt
   setGPIO1Mode, GPO, pPVTLED
   setGPIO2Mode, GPO, pRTKLED
   setCOMSettings, COM1, baud230400      (optional: skips ArduPilot's ~25 s baud hunt)
   exeCopyConfigFile, Current, Boot
   exeResetReceiver, Hard, none
   ```

   Everything else needed for heading is sent by the driver at every boot
   (`sso ... +AttCovEuler+AuxAntPositions`, `sga, MultiAntenna` - the latter is
   even the G5 default, p.112) and is not saved on the receiver.
3. **Antenna sign convention.** SBF reports the main→auxiliary vector as
   heading. Mount ANT1 (main) and ANT2 (aux) so the baseline matches the
   `GPS1_MB_OFS_*` embedded here; if the physical layout is reversed, flip
   the sign of `GPS1_MB_OFS_X` rather than swapping cables.

Still to measure on hardware: heading output rate (the datasheet states 20 Hz
for position only; the driver asks for 10 Hz), dual-antenna pre-amp gain
window (15–35 dB, ANT1/ANT2 within 5 dB), and the RM3100 axis mask inherited
from AP-RTK dual.

Build (verified 2026-09-02 with this hwdef: bootloader 29,080 B of 32 KB;
AP_Periph 205,972 B used, 252,768 B free - `HAL_GCS_ENABLED` fits easily).
Needs novaX patch `0004-novax-f412-bootloader-otg-hs-guard.patch`
(`scripts/apply_ap_patches.sh`): the F412 has no OTG_HS block.

```bash
scripts/build_ap.sh AP-RTK_G5H AP_Periph
```

Outputs land in `releases/AP-RTK_G5H/ardupilot/` as
`AP-RTK_G5H-v<VERSION>.apj / .bin / .hex / _with_bl.hex` (+ `AP-RTK_G5H_bl.*`).

Flash: first `AP-RTK_G5H-v<VERSION>_with_bl.hex` over SWD, or over USB-C with the ST ROM
DFU (hold BOOT0 while connecting -> `0483:df11`). Afterwards update over
DroneCAN, over USB with `uploader.py` / Mission Planner (ArduPilot bootloader,
`SERIAL_ORDER OTG1`), or with the buttonless soft-DFU (`param4=99`).

Layout:

- `hwdef.dat`: AP_Periph hardware definition
- `hwdef-bl.dat`: bootloader hardware definition
- `defaults.parm`: embedded node parameters (moving-base offsets)
