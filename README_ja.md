# novaX フライトコントローラー

[English](README.md) | [한국어](README_ko.md) | [中文](README_zh.md)

novaX フライトコントローラーおよび DroneCAN ペリフェラル向けのボード定義、ビルドスクリプト、ファームウェアリリース。

## 対応ボード

| ボード | MCU | IMU | 気圧計 | コンパス | GPS | ファームウェア |
|--------|-----|-----|--------|----------|-----|----------------|
| AF-F4 nano | STM32F405 | ICM-42688-P | SPL06 | QMC5883P (外付け) | MAX-M10S | ArduPilot / Betaflight |
| AF-H7 nano | STM32H743 | デュアル ICM-42688-P | DPS310 | IST8310 (内蔵) | - | ArduPilot / Betaflight |
| AF-F7 mini&nbsp;‡ | STM32F765 | ICM-20689 + ICM-20602 + BMI055 | MS5611 | IST8310 (内蔵) | - | ArduPilot |
| AF-H7E&nbsp;‡ | STM32H753 | ICM-42688-P + BMI088 + ICM-20649 | 2× ICP-20100 | RM3100 | - | ArduPilot |
| AP-RTK dual&nbsp;† | STM32F412 | - | - | RM3100 | デュアルアンテナ RTK (ムービングベースライン) | ArduPilot AP_Periph |

† **DroneCAN ペリフェラル** (GPS + コンパスノード)。フライトコントローラーではありません。CUAV C-RTK2-HP ベース、ボード ID `1085`（CUAV と同一に維持 → DroneCAN OTA 互換）。

‡ 冗長 IMU を備えた**オートパイロット級**ボード: AF-F7 mini は PWM 出力を直接駆動（IO コプロセッサなし）し、AF-H7E は STM32F103 IO コプロセッサとイーサネットを搭載したモジュラー設計です。

すべてのフライトコントローラーは novaX-ALUX 予約レンジ `6200`–`6209` 内のボード ID を使用します: AF-H7 nano `6200`、AF-F7 mini `6201`、AF-H7E `6202`、AF-F4 nano `6203`（AF-F4 nano は SpeedyBee F4 の ID ではなく独自の novaX ID を使用するようになりました）。AP-RTK dual ペリフェラルは DroneCAN OTA 互換のため CUAV ID `1085` を維持します。

## リポジトリ構成

```
├── firmware/
│   ├── ardupilot/              # ArduPilot ソース (git submodule)
│   └── betaflight/             # Betaflight ソース (git submodule)
├── boards/
│   ├── AF-F4_nano/             # フライトコントローラー
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   ├── betaflight/         # config.h
│   │   └── docs/               # 回路図
│   ├── AF-H7_nano/             # フライトコントローラー
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   ├── betaflight/         # config.h
│   │   └── docs/               # 回路図
│   ├── AF-F7_mini/             # フライトコントローラー (no IOMCU)
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   └── docs/               # 回路図 + ネットリスト
│   ├── AF-H7E/                 # フライトコントローラー (modular, Ethernet)
│   │   ├── ardupilot/          # hwdef.dat, hwdef-bl.dat, defaults.parm
│   │   └── docs/               # 回路図 + ネットリスト
│   └── AP-RTK_dual/            # DroneCAN AP_Periph ペリフェラル (GPS + コンパス)
│       ├── ardupilot/          # hwdef.dat, hwdef-bl.dat
│       └── metadata.yaml
├── scripts/
│   ├── sync_ap_board.sh        # ボード定義を AP ソースツリーへシンボリックリンク
│   ├── build_ap.sh             # 構成 + ビルド + パッケージ化 (ArduPilot)
│   ├── build_bf.sh             # ビルド + パッケージ化 (Betaflight)
│   ├── package_fw.sh           # ファームウェア成果物を releases/ に収集
│   └── release.sh              # GitHub Release を公開（個別ファイル）
├── VERSION                     # 共有 novaX ファームウェアバージョン（全 FC 共通）
├── releases/                   # ローカルビルド出力 (gitignored)
│   └── <board>/
│       ├── ardupilot/          # .apj, .hex, bootloader
│       └── betaflight/         # .hex, .bin
└── GitHub Releases             # 公開ファームウェア（ボードごとの個別ファイル）
```

## はじめに

### クローン

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/novaX-ALUX/fc.git
cd flight_controller
```

### ArduPilot ビルド

フライトコントローラー (機体ファームウェア):

```bash
./scripts/build_ap.sh AF-F4_nano copter
./scripts/build_ap.sh AF-H7_nano copter
./scripts/build_ap.sh AF-F7_mini copter
./scripts/build_ap.sh AF-H7E copter
```

DroneCAN ペリフェラル (AP_Periph ファームウェア — ターゲットに `AP_Periph` を指定):

```bash
./scripts/build_ap.sh AP-RTK_dual AP_Periph
```

ブートローダーは初回実行時に存在しなければ自動でビルドされます。ArduPilot のビルドには標準の ArduPilot Python パッケージ(`pymavlink`, `empy==3.3.4`, `intelhex` など)が必要で、結合 `*_with_bl.hex` の生成には **`intelhex`** モジュールが必須です。

### Betaflight ビルド

```bash
# ARM ツールチェーンのインストール (初回のみ、GCC 13.3.1 が必要)
cd firmware/betaflight && make arm_sdk_install && cd ../..

# ビルド
./scripts/build_bf.sh AF-F4_nano
./scripts/build_bf.sh AF-H7_nano
```

### 出力

ファームウェア成果物は `releases/<board>/` に収集されます:

```bash
ls releases/AF-F4_nano/ardupilot/
# arducopter.apj  arducopter_with_bl.hex  AF-F4_nano_bl.bin  ...

ls releases/AP-RTK_dual/ardupilot/
# AP_Periph.bin  AP_Periph.apj  AP_Periph_with_bl.hex  AP-RTK_dual_bl.bin  ...
```

## ファームウェアバージョン

すべてのフライトコントローラーは**単一の** novaX バージョンを共有し、リポジトリ直下の `VERSION` ファイル（例: `0.2.0`）で定義します。ビルド時に `build_ap.sh` がこれをファームウェアへ埋め込むため、Mission Planner / QGC では次のように表示されます:

```
novaX v0.2.0 (92b0cd78)
```

上流の ArduPilot バージョンは別途 `fw_string_original` に保持され、git ハッシュは末尾に自動付加されます。DroneCAN ペリフェラル（AP_Periph）は独自のバージョン系統で、共有 FC バージョンは付与されません。

## リリース公開

リリースはファームウェアを**個別ファイル**として公開します（zip なし）。ボードごとに 1 セットを単一タグの下に配置します。

```bash
# 1. 共有バージョンを更新
echo 0.2.0 > VERSION

# 2. 各フライトコントローラーをビルド（バージョンは自動で埋め込まれます）
./scripts/build_ap.sh AF-F4_nano copter
./scripts/build_ap.sh AF-F7_mini copter
./scripts/build_ap.sh AF-H7_nano copter
./scripts/build_ap.sh AF-H7E    copter

# 3. 公開。タグは VERSION と一致する必要があります（vX.Y.Z）。ペリフェラルは除外されます
./scripts/release.sh v0.2.0
```

リポジトリ直下に `GITHUB_ACCESS_TOKEN=<token>` を含む `.env` が必要です（gitignored）。`DRY_RUN=1 ./scripts/release.sh v0.2.0` で公開せずにプレビューできます。

## 書き込み

フライトコントローラー:

| 方法 | ファイル | タイミング |
|------|----------|------------|
| STLink / DFU | `*_with_bl.hex` | 初回書き込み (ブートローダー含む) |
| Mission Planner | `.apj` | ArduPilot OTA 更新 |
| BF Configurator | `.hex` | Betaflight 更新 |

DroneCAN ペリフェラル (例: AP-RTK dual — USB DFU なし):

| 方法 | ファイル | タイミング |
|------|----------|------------|
| STLink / SWD | `AP_Periph_with_bl.hex` | 初回書き込み (ブートローダー + アプリ、`0x08000000`) |
| Mission Planner → DroneCAN | `AP_Periph.bin` | CAN 経由のファームウェア更新 |

## 仕組み

ボード定義はファームウェアソースから分離されて `boards/` に置かれます。`sync_ap_board.sh` スクリプトが ArduPilot ソースツリーへの相対シンボリックリンクを作成し、ビルドシステムが認識できるようにします。

ファームウェアソースの更新はボード設定とは独立です:

```bash
cd firmware/ardupilot && git pull
```

## ライセンス

ハードウェア設計ファイルは novaX-ALUX 専有です。
ファームウェア定義は各アップストリームのライセンス (GPLv3) に従います。
