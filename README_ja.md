# novaX FC

[English](README.md) | [한국어](README_ko.md)

開発元は[novaX-ALUX/fc](https://github.com/novaX-ALUX/fc)です。FC・派生設定7種類を管理します。GNSSは別の非公開リポジトリ[novaX-ALUX/gnss](https://github.com/novaX-ALUX/gnss)に移動しました。ArduPilotも独立した共有リポジトリで、FCのサブモジュールではありません。

## 現在の全ボード設定

実際のhwdef.dat、ブートローダーID、各VERSION、設定ファイルによる一覧です。設定の存在は実機認定・公開完了を意味しません。Build MCU targetはソフトウェア名です。AF-F7 miniの宣言部品はSTM32F765IIK6でバックエンドはSTM32F767xx、AF-H7EはSTM32H753IIK6とSTM32H743xxです。交換部品番号と区別してください。

<!-- board-inventory:start -->
| Board directory | Scope | Build MCU target | Board ID | Source version | Configuration present |
|---|---|---|---|---|---|
| [AD-ME1](boards/AD-ME1/ardupilot/) | Rebrand variant | `STM32F405xx` | 6203 | 0.1.0 | ArduPilot |
| [AF-F4_nano](boards/AF-F4_nano/ardupilot/) | FC | `STM32F405xx` | 6203 | 1.2.3 | ArduPilot + Betaflight config |
| [AF-F4_nano_v2](boards/AF-F4_nano_v2/ardupilot/) | FC | `STM32F405xx` | 6204 | 1.0.11 | ArduPilot |
| [AF-F4_T10_nano](boards/AF-F4_T10_nano/ardupilot/) | FC | `STM32F405xx` | 6203 | 1.3.4 | ArduPilot |
| [AF-F7_mini](boards/AF-F7_mini/ardupilot/) | FC | `STM32F767xx` | 6201 | 1.3.0 | ArduPilot |
| [AF-H7_nano](boards/AF-H7_nano/ardupilot/) | FC | `STM32H743xx` | 6200 | 1.2.3 | ArduPilot + Betaflight config |
| [AF-H7E](boards/AF-H7E/ardupilot/) | FC | `STM32H743xx` | 6202 | 1.3.0 | ArduPilot |
<!-- board-inventory:end -->

## 実際の構造

将来の構想ではなく現在の構造です。ローカルの未追跡製品資料は新規cloneで取得できるとは限りません。GitHub Releasesは遠隔サービスでありソース内のフォルダーではありません。

```text
fc/
├─ boards/
│  ├─ AD-ME1/
│  ├─ AF-F4_nano/
│  ├─ AF-F4_nano_v2/
│  ├─ AF-F4_T10_nano/
│  ├─ AF-F7_mini/
│  ├─ AF-H7_nano/
│  └─ AF-H7E/
├─ firmware/
│  └─ betaflight/    # pinned Git submodule
├─ patches/ardupilot/
├─ scripts/          # sync, build, package, release, validation
├─ VERSION           # fallback; boards/<board>/VERSION takes priority
├─ VERSIONING.md
├─ build/            # generated, ignored
└─ releases/         # generated, ignored
```

## ビルドと独立バージョン

固定upstreamの依存関係を備えたLinux/WSLを使用します。ビルド前にnovaXパッチを適用し警告を解決します。既存の未コミット作業を上書きしません。Betaflight設定はAF-F4_nanoとAF-H7_nanoのみで、設定存在はビルド検証の代わりではありません。

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/novaX-ALUX/fc.git
# New, empty shared destination only; never overwrite an existing checkout.
git clone --branch novax-workspace https://github.com/novaX-ALUX/ardupilot.git _shared/ardupilot
# Select the exact ardupilot-source.json commit before initializing submodules.
git -C _shared/ardupilot submodule update --init --recursive
bash _shared/ardupilot/Tools/novax/install_toolchain.sh # ArduPilot GCC 10.2.1
cd fc
bash scripts/apply_ap_patches.sh
bash scripts/build_ap.sh AF-F4_nano copter
# GNSS builds run from the separate gnss repository.
```

優先順位はNOVAX_VERSION → boards/<board>/VERSION → ルートVERSION → devです。FC文字列はnovaX Copter v1.3.0のように機体種類を含み、AP_Periph出力名はボード別バージョンです。全製品共通バージョンではありません。[VERSIONING.md](VERSIONING.md)を参照してください。

## 公開・更新の制限

2026-09-06にAF-* 6種類とAP-RTK dual/G5Hの既存ボード別公開を確認しました。AD-ME1とX20Dのボード別公開は未確認です。VERSIONは出荷承認ではありません。

release.shは既存アセットを上書きできます。承認・ビルド検証後の未公開ボード別タグを使用してください。DRY_RUNは公開しませんが署名対象には署名器・鍵が必要です。実公開はGit除外のGITHUB_ACCESS_TOKENを使用します。AF-F4_nano_v2署名を回避せず、ワークスペースのカタログ署名器またはAFF4T10_FWSIGを使います。

```bash
# Set BOARD and NEW_TAG only for the reviewed, built, unreleased product.
DRY_RUN=1 ./scripts/release.sh "${NEW_TAG:?set unreleased board-scoped tag}" "${BOARD:?set board directory name}"
```

製品・機体種類に一致するファイルのみ使用します。AD-ME1/AF-F4_nano/AF-F4_T10_nanoはID 6203を共有しますがピン・機能互換の保証ではありません。v2は6204です。FC .apjはUSBブートローダー/シリアル更新、一致する_with_bl.hexはボード固有DFU/SWD復旧です。全ボードのボタンなしDFUを仮定しません。

AP-RTK dualはDroneCAN更新とSWD復旧を使い、受信機USBはMCU DFUではありません。G5HはDroneCANまたはボード固有MCU USB/DFU/SWDです。X20Dは開発中で検証済み公開ではありません。[Web Updater](https://novax-alux.github.io/parts-catalog/update/)は表示されたFC向けで、全外設対応ではありません。

## 文書回帰検査

```bash
python3 scripts/validate_docs.py
```

Hardware design files are proprietary to novaX-ALUX. Firmware definitions follow their respective upstream licenses (GPLv3).
