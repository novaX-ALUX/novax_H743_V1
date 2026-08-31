# novaX 飞控

[English](README.md) | [한국어](README_ko.md) | [日本語](README_ja.md)

novaX 系列飞控与 DroneCAN 外设的板级定义、构建脚本和固件发布产物。

## 支持的板卡

| 板卡 | MCU | IMU | 气压计 | 罗盘 | GPS | 固件 |
|------|-----|-----|--------|------|-----|------|
| AF-F4 nano | STM32F405 | ICM-42688-P | SPL06 | QMC5883P (外置) | MAX-M10S | ArduPilot / Betaflight |
| AF-H7 nano | STM32H743 | 双 ICM-42688-P | DPS310 | IST8310 (内置) | - | ArduPilot / Betaflight |
| AF-F7 mini&nbsp;‡ | STM32F765 | ICM-20689 + ICM-20602 + BMI055 | MS5611 | IST8310 (内置) | - | ArduPilot |
| AF-H7E&nbsp;‡ | STM32H753 | ICM-42688-P + BMI088 + ICM-20649 | 2× ICP-20100 | RM3100 | - | ArduPilot |
| AP-RTK dual&nbsp;† | STM32F412 | - | - | RM3100 | 双天线 RTK (移动基线) | ArduPilot AP_Periph |

† **DroneCAN 外设**（GPS + 罗盘节点），并非飞控。基于 CUAV C-RTK2-HP，板卡 ID `1085`（与 CUAV 保持一致 → 兼容 DroneCAN OTA 更新）。

‡ **自动驾驶仪级别**飞控，具备冗余 IMU。AF-F7 mini 直接驱动 PWM 输出（无 IO 协处理器）；AF-H7E 是模块化设计，带 STM32F103 IO 协处理器和以太网。

所有飞控均使用 novaX-ALUX 保留段 `6200`–`6209` 内的板卡 ID：AF-H7 nano `6200`、AF-F7 mini `6201`、AF-H7E `6202`、AF-F4 nano `6203`（AF-F4 nano 现已改用独立的 novaX ID，不再沿用 SpeedyBee F4 的 ID）。AP-RTK dual 外设保留 CUAV ID `1085` 以兼容 DroneCAN OTA。

## 目录结构

```
├── firmware/
│   ├── ardupilot/              # ArduPilot 源码 (git submodule)
│   └── betaflight/             # Betaflight 源码 (git submodule)
├── boards/
│   ├── AF-F4_nano/             # 飞控
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   ├── betaflight/         # config.h
│   │   └── docs/               # 原理图
│   ├── AF-H7_nano/             # 飞控
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   ├── betaflight/         # config.h
│   │   └── docs/               # 原理图
│   ├── AF-F7_mini/             # 飞控 (无 IOMCU)
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   └── docs/               # 原理图 + 网表
│   ├── AF-H7E/                 # 飞控 (模块化, 以太网)
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   └── docs/               # 原理图 + 网表
│   └── AP-RTK_dual/            # DroneCAN AP_Periph 外设 (GPS + 罗盘)
│       ├── ardupilot/          # hwdef.dat, hwdef-bl.dat
│       └── metadata.yaml
├── scripts/
│   ├── sync_ap_board.sh        # 将板级定义软链到 AP 源码树
│   ├── build_ap.sh             # 配置 + 编译 + 打包 (ArduPilot)
│   ├── build_bf.sh             # 编译 + 打包 (Betaflight)
│   ├── package_fw.sh           # 收集固件产物到 releases/
│   └── release.sh              # 发布 GitHub Release（单个文件）
├── VERSION                     # 共享的 novaX 固件版本（所有飞控通用）
├── releases/                   # 本地编译产物（已 gitignore）
│   └── <board>/
│       ├── ardupilot/          # .apj, .hex, bootloader
│       └── betaflight/         # .hex, .bin
└── GitHub Releases             # 发布的固件（每块板各自的单个文件）
```

## 快速开始

### 克隆

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/novaX-ALUX/fc-boards.git
cd flight_controller
```

### 编译 ArduPilot

飞控（机型固件）：

```bash
./scripts/build_ap.sh AF-F4_nano copter
./scripts/build_ap.sh AF-H7_nano copter
./scripts/build_ap.sh AF-F7_mini copter
./scripts/build_ap.sh AF-H7E copter
```

DroneCAN 外设（AP_Periph 固件 —— 目标传入 `AP_Periph`）：

```bash
./scripts/build_ap.sh AP-RTK_dual AP_Periph
```

首次编译时 bootloader 会自动构建。ArduPilot 编译需要标准的 ArduPilot Python 包（`pymavlink`、`empy==3.3.4`、`intelhex` 等）；生成合并的 `*_with_bl.hex` 必须有 **`intelhex`** 模块。

### 编译 Betaflight

```bash
# 安装 ARM 工具链（仅需一次，要求 GCC 13.3.1）
cd firmware/betaflight && make arm_sdk_install && cd ../..

# 编译
./scripts/build_bf.sh AF-F4_nano
./scripts/build_bf.sh AF-H7_nano
```

### 产物

固件产物收集在 `releases/<board>/` 下：

```bash
ls releases/AF-F4_nano/ardupilot/
# arducopter.apj  arducopter_with_bl.hex  AF-F4_nano_bl.bin  ...

ls releases/AP-RTK_dual/ardupilot/
# AP_Periph.bin  AP_Periph.apj  AP_Periph_with_bl.hex  AP-RTK_dual_bl.bin  ...
```

## 固件版本

所有飞控共用**一个** novaX 版本号，定义在仓库根目录的 `VERSION` 文件里（如 `0.2.0`）。编译时 `build_ap.sh` 会把它注入固件，于是 Mission Planner / QGC 显示：

```
novaX v0.2.0 (92b0cd78)
```

上游 ArduPilot 版本单独保存在 `fw_string_original`，git hash 自动追加在末尾。DroneCAN 外设（AP_Periph）走独立的版本轨，不会被打上共享的飞控版本号。

## 发布固件

发布产物为**单个文件**（不打 zip）——每块板一组，统一挂在一个 tag 下。

```bash
# 1. 更新共享版本号
echo 0.2.0 > VERSION

# 2. 逐块编译飞控（版本号会自动注入）
./scripts/build_ap.sh AF-F4_nano copter
./scripts/build_ap.sh AF-F7_mini copter
./scripts/build_ap.sh AF-H7_nano copter
./scripts/build_ap.sh AF-H7E    copter

# 3. 发布。tag 必须与 VERSION 一致（vX.Y.Z）；外设自动排除
./scripts/release.sh v0.2.0
```

需要在仓库根放置含 `GITHUB_ACCESS_TOKEN=<token>` 的 `.env`（已 gitignore）。用 `DRY_RUN=1 ./scripts/release.sh v0.2.0` 可预览而不实际发布。

## 烧录方式

飞控：

| 方式 | 文件 | 场景 |
|------|------|------|
| STLink / DFU | `*_with_bl.hex` | 首次烧录（含 bootloader） |
| Mission Planner | `.apj` | ArduPilot OTA 更新 |
| BF Configurator | `.hex` | Betaflight 更新 |

DroneCAN 外设（如 AP-RTK dual —— 无 USB DFU）：

| 方式 | 文件 | 场景 |
|------|------|------|
| STLink / SWD | `AP_Periph_with_bl.hex` | 首次烧录（bootloader + app，`0x08000000`） |
| Mission Planner → DroneCAN | `AP_Periph.bin` | 通过 CAN 更新固件 |

## 工作原理

板级定义放在 `boards/` 下，与固件源码分离。`sync_ap_board.sh` 通过相对路径软链将其挂载到 ArduPilot 源码树，编译系统即可识别。

更新固件源码不影响板级配置：

```bash
cd firmware/ardupilot && git pull
```

## 许可证

硬件设计文件为 novaX-ALUX 专有。
固件定义文件遵循上游许可证（GPLv3）。
