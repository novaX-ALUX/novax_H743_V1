# novaX ArduPilot patches

The `firmware/ardupilot` submodule is pinned to **upstream** ArduPilot, so core-source fixes
that are not expressible as hwdef overlays are kept here as patches and re-applied after a
fresh checkout / `git submodule update` via `scripts/apply_ap_patches.sh`.

## Patches
- **0001-novax-software-dfu-board.patch** — buttonless software DFU (MAVLink
  `PREFLIGHT_REBOOT_SHUTDOWN` param4=99, magic 42/24/71 → `Util::boot_to_dfu()`). One
  consolidated patch, two mechanisms by MCU family:
  - **F4 / F7 — software jump.** `board.c __early_init()` (bootloader build) reads the
    `boot_to_dfu` persistent flag and jumps to the ST ROM system bootloader with a full deinit
    (upstream's `system.cpp __entry_hook()` is dead in this pinned ChibiOS). `Util::boot_to_dfu()`
    drops USB D+ (`usbDisconnectBus`) before the reset so the host re-enumerates the ROM DFU
    instead of keeping the stale CDC handle. ROM base: F4=0x1FFF0000, F7=0x1FF00000.
  - **H7 (AF-H7E / H753) — option-byte cold boot.** `Util::boot_to_dfu()` commits
    `BOOT_CM7_ADD0=0x1FF00000` (`flash.c stm32_flash_set_boot_address0`, RM0433 both-bank-idle
    OPTSTART sequence) then `NVIC_SystemReset()` → the ROM cold-boots into USB DFU (0483:DF11).
    After a DFU flash the ST ROM "leave" is a *jump* to 0x08000000 (not a reset), so
    `AP_Bootloader.cpp main()` **self-heals**: if `BOOT_CUR==0x1FF0` it restores
    `BOOT_ADD0=0x08000000` and `NVIC_SystemReset()` → the app cold-boots with clean USB, no
    power cycle. The F4/F7 `board.c` jump is gated `!defined(STM32H7)` (the H753 jump leaves USB
    dark), so it never touches the H7 bootloader binary.

  (This supersedes the former split 0001 board.c / 0002 usb-disconnect patches, which were the
  F4-only jump approach; they are consolidated here alongside the H7 BOOT_ADD0 path.)

- **0002-novax-signing-timestamp-throttle.patch** — makes the forced signing-timestamp save
  opt-out via `AP_MAVLINK_SIGNING_FORCE_SAVE_TIMESTAMP` (`GCS_MAVLink/GCS_Signing.cpp`).
  **Default stays `1`, i.e. upstream behaviour, so boards that do not define it are untouched.**
  - *Why:* `AP_GPS` calls `AP::rtc().set_utc_usec()` on every GPS update with a 3D fix (5-10 Hz);
    each accepted update ran `update_signing_timestamp()` → `save_signing_timestamp(true)` →
    a 44-byte write into `StorageManager::StorageKeys`. Upstream assumes that storage is FRAM
    ("structure stored in FRAM"). On a flash-emulated storage board (`STORAGE_FLASH_PAGE`, no
    FRAM) the sector fills within tens of seconds and the resulting erase "stops the whole MCU"
    (`AP_HAL_ChibiOS/Storage.cpp`) for ~250 ms, overrunning the UART FIFOs → GPS overruns,
    "GPS not healthy", delayed frames. Measured on AF-F4_nano_v2: repeated 245-262 ms loops with
    signing ON, none with signing OFF; `MaxT` 2.57-2.92 ms vs 245+ ms.
  - *Opt-out:* `AF-F4_nano_v2/hwdef.dat` sets `AP_MAVLINK_SIGNING_FORCE_SAVE_TIMESTAMP 0`, which
    falls back to the periodic 30 s save (`GCS_Common.cpp` already uses that granularity for the
    non-forced call site). Signing itself stays fully enabled.
  - *Not a flight-safety issue by itself:* `Storage::_flash_erase_ok()` only permits an erase while
    disarmed and `AP_FlashStorage::write()` returns false instead of blocking when an erase is not
    allowed, so the stall cannot occur in flight — it breaks ground/pre-arm operation.

- **0003-novax-m10-lna-mode.patch** — pins the u-blox **M10 internal LNA gain** per board.
  The receiver default is not stable across module firmware: SPG 5.10
  (UBX-21035062) documents `CFG-HW-RF_LNA_MODE` default `0 (NORMAL)`, SPG 5.20
  (UBXDOC-304424225-20128) documents `1 (LOWGAIN)`, so an identical board can ship
  with a different front-end gain. Adds the key to `ConfigKey` and a gated entry to
  `config_M10[]`, selected by `AP_GPS_UBLOX_M10_LNA_MODE` (`0` NORMAL / `1` LOWGAIN /
  `2` BYPASS). **Default `-1` sends nothing, i.e. upstream behaviour, so boards that
  do not define it are untouched.** `AF-F4_nano_v2` sets `0` (bare module, no external
  LNA). ArduPilot writes `config_M10` over VALSET `RAM|BBR`; per the interface
  description the RAM layer is "effective immediately", so no GPS reset is required.

## Verified (hardware)
- **AF-F4_T10_nano (STM32F405):** software-jump DFU — `param4=99` → `0483:df11` cleanly.
- **AF-H7E (STM32H753), 2026-07:** BOOT_ADD0 cold-boot DFU entry + `flash_dfu.py`/WebUSB flash +
  bootloader self-heal auto-boot (no power cycle). Full round-trip verified on the bench.
- **F7:** built with the F4/F7 jump path but **not hardware-verified** (no board on hand).
