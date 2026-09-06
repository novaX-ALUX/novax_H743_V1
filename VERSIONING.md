# 보드별 독립 펌웨어 버전

현재 소스의 정본은 `boards/<board>/VERSION`이다. 한 보드를 변경해도 다른 보드의 버전을 자동으로 올리지 않는다.

## 버전 선택

1. `NOVAX_VERSION` 환경변수: 검토된 일회성 override
2. `boards/<board>/VERSION`: 평상시 정본
3. 루트 `VERSION`: 보드 파일이 없는 경우의 fallback
4. `dev`: 위 값이 모두 없을 때

`build_ap.sh`의 FC 문자열은 `novaX Copter v1.3.0`, `novaX Plane v1.3.0`처럼 기체 종류를 포함한다. upstream 버전과 Git 해시는 별도 정보를 유지한다. AP_Periph는 이 FC 문자열을 주입하지 않으며 `package_fw.sh`가 `<board>-v<version>` 파일명으로 산출물을 구분한다.

## 현재 설정 전체

아래 표는 소스 정의의 현재 값이다. 출시 승인·실기 통과·업로드 완료 여부를 VERSION 파일만으로 판단하지 않는다. 실제 게시된 버전은 [릴리스 목록](https://github.com/novaX-ALUX/fc/releases)과 파일 해시를 확인한다.

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
| [AP-RTK_dual](boards/AP-RTK_dual/ardupilot/) | GNSS (transitional) | `STM32F412Rx` | 1085 | 0.1.0 | AP_Periph |
| [AP-RTK_G5H](boards/AP-RTK_G5H/ardupilot/) | GNSS (transitional) | `STM32F412Rx` | 6206 | 0.1.0 | AP_Periph |
| [AP-RTK_X20D](boards/AP-RTK_X20D/ardupilot/) | GNSS (transitional) | `STM32F412Rx` | 6205 | 0.1.0 | AP_Periph |
<!-- board-inventory:end -->

## 릴리스 태그와 산출물

- 보드별 태그 `<board>-vX.Y.Z`는 해당 보드 VERSION과 대조한다.
- 과거 글로벌 태그 `vX.Y.Z` 지원은 남아 있지만 루트 VERSION과만 대조한다. 제품별 출시에는 보드별 태그와 명시적인 보드 인자를 사용한다.
- 배포된 태그에 같은 이름의 자산을 덮어쓰면 기존 해시·서명·카탈로그가 불일치할 수 있다. 기존 태그를 임의 재사용하지 않는다.
- `releases/<board>/ardupilot/`의 FC 내부 파일은 `arducopter.apj`/`arduplane.apj` 등이며 게시 때 제품·기체명이 붙는다. 여러 기체 파일을 한 보드 이름으로 혼동하지 않는다.
- AP_Periph 내부 파일은 처음부터 `<board>-v<version>.apj/.bin/_with_bl.hex` 형식이다. X20D의 개발 버전 파일은 공개 펌웨어 출시를 의미하지 않는다.
- AF-F4_nano_v2의 서명 대상 `.apj`와 `_with_bl.hex`에는 대응하는 `.aff4t10.json`이 필요하다. 서명·버전 불일치 검사를 우회하지 않는다.

검사: `python3 scripts/validate_docs.py`. 보드 ID·버전·설정 목록이 바뀌면 README 3개 언어판과 이 표도 함께 갱신해야 검사에 통과한다. 중국어 번역 및 선택 링크는 제거했다.
