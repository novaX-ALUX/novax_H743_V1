# novaX FC

[English](README.md) | [日本語](README_ja.md)

개발 정본은 [novaX-ALUX/fc](https://github.com/novaX-ALUX/fc)다. FC·리브랜딩 설정 7종을 관리한다. GNSS 제품 소스는 별도 비공개 저장소 [novaX-ALUX/gnss](https://github.com/novaX-ALUX/gnss)에 있다. ArduPilot도 공용 독립 저장소로 분리했으며 FC 서브모듈이 아니다.

## 현재 보드 설정 전체 목록

실제 hwdef.dat·부트로더 ID·보드별 VERSION·설정 경로를 대조한 목록이다. **설정 존재는 실기 승인이나 펌웨어 출시 완료를 뜻하지 않는다.** Build MCU target은 소프트웨어 백엔드다. AF-F7 mini의 선언 부품은 STM32F765IIK6이고 백엔드는 STM32F767xx, AF-H7E는 STM32H753IIK6와 STM32H743xx다. 백엔드명을 실제 교체 부품 번호로 해석하지 않는다.

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

## 실제 저장소 구조

향후 계획도가 아니라 현재 구조다. 로컬 제품 회로·문서 중 공개 Git에서 추적되지 않는 파일은 새 clone에 포함된다고 안내하지 않는다. GitHub Releases는 원격 서비스이지 소스 안의 폴더가 아니다.

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

## 빌드와 제품별 독립 버전

고정된 upstream 소스에 필요한 의존성을 갖춘 Linux/WSL에서 빌드한다. 검토된 novaX 패치를 먼저 적용하고 경고가 있으면 해결 전 출시하지 않는다. 미커밋 작업이 있는 기존 서브모듈을 덮어쓰거나 임의로 갱신하지 않는다. Betaflight 설정은 AF-F4_nano·AF-H7_nano 두 곳에만 있으며 설정 존재가 이번 빌드 성공을 뜻하지 않는다.

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/novaX-ALUX/fc.git
# New, empty shared destination only; never overwrite an existing checkout.
git clone --branch novax-workspace https://github.com/novaX-ALUX/ardupilot.git _shared/ardupilot
# Select the exact ardupilot-source.json commit before initializing submodules.
git -C _shared/ardupilot submodule update --init --recursive
cd fc
bash scripts/apply_ap_patches.sh
bash scripts/build_ap.sh AF-F4_nano copter
# GNSS builds run from the separate gnss repository.
```

버전 우선순위는 `NOVAX_VERSION` → `boards/<board>/VERSION` → 루트 `VERSION` → `dev`다. FC 표시에는 `novaX Copter v1.3.0`처럼 기체 종류가 포함되고 AP_Periph 파일명은 보드별 버전을 쓴다. 전 제품이 단일 공통 버전을 쓰는 것이 아니다. [VERSIONING.md](VERSIONING.md)를 따른다.

## 릴리스·업데이트 제한

2026-09-06 릴리스 목록에서 AF-* 6종·AP-RTK dual·AP-RTK G5H의 기존 보드별 릴리스를 확인했다. AD-ME1·AP-RTK X20D의 보드별 릴리스는 확인되지 않았다. VERSION 파일이 있다고 출하 승인된 것이 아니다.

`release.sh`는 기존 릴리스 자산을 덮어쓸 수 있다. 승인과 빌드 검증을 마친 뒤 미게시 보드별 태그를 사용한다. DRY_RUN은 게시하지 않지만 서명 대상 보드는 로컬 서명기·키가 필요하다. 실제 게시에는 Git 제외된 GITHUB_ACCESS_TOKEN이 필요하며 AF-F4_nano_v2 서명 검사를 우회하지 않는다. 작업공간의 카탈로그 서명기 또는 AFF4T10_FWSIG 경로를 사용한다.

```bash
# Set BOARD and NEW_TAG only for the reviewed, built, unreleased product.
DRY_RUN=1 ./scripts/release.sh "${NEW_TAG:?set unreleased board-scoped tag}" "${BOARD:?set board directory name}"
```

제품·기체 종류가 일치하는 파일만 사용한다. AD-ME1·AF-F4_nano·AF-F4_T10_nano는 ID 6203을 공유하므로 ID가 같아도 기능·핀맵 호환을 보장하지 않는다. AF-F4_nano_v2는 6204다. FC .apj는 USB 부트로더/시리얼 업데이터를, 일치하는 _with_bl.hex는 제품별 DFU/SWD 복구 경로를 사용한다. 모든 보드에 버튼 없는 DFU가 있다고 가정하지 않는다.

AP-RTK dual은 DroneCAN 업데이트·SWD MCU 복구를 사용하며 수신기 USB는 MCU DFU가 아니다. AP-RTK G5H는 DroneCAN 또는 보드별 MCU USB 부트로더/DFU/SWD를 사용한다. AP-RTK X20D는 개발 대상이며 확인된 공개 릴리스가 아니다. 카탈로그 [Web Updater](https://novax-alux.github.io/parts-catalog/update/)는 표시된 FC 파일을 다루며 모든 주변장치를 지원하지 않는다.

## 문서 회귀 검사

```bash
python3 scripts/validate_docs.py
```

Hardware design files are proprietary to novaX-ALUX. Firmware definitions follow their respective upstream licenses (GPLv3).
