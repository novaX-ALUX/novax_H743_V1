# 펌웨어 버전 규칙 — 하드웨어(보드)별 독립 버전

각 보드는 **자기만의 버전**을 가진다. 한 보드를 고쳐도 다른 보드 버전은 올라가지 않는다.

## 버전 소스
보드 버전은 **`boards/<board>/VERSION`** 파일 한 줄(`X.Y.Z`)에 있다.

빌드 시 `scripts/build_ap.sh`가 이 순서로 버전을 정한다:
1. `NOVAX_VERSION` 환경변수 (일회성 오버라이드)
2. **`boards/<board>/VERSION`** ← 평상시 여기
3. 루트 `VERSION` (보드 파일이 없을 때의 기본값)
4. `dev`

정해진 버전은 GCS에 `novaX v<X.Y.Z> (g<hash>)`로 표시된다(`AP_CUSTOM_FIRMWARE_STRING`).

## 보드 버전 올리기
```bash
echo "0.2.4" > boards/AF-F7_mini/VERSION   # 그 보드만 올림
scripts/build_ap.sh AF-F7_mini copter      # boards/AF-F7_mini/VERSION 자동 사용
```

## 릴리스 태그
- **보드별 태그** `‹board›-vX.Y.Z` (예: `AF-F7_mini-v0.2.4`) → `scripts/release.sh`가 `boards/‹board›/VERSION`과 대조. 불일치면 거부(의도적이면 `ALLOW_VERSION_MISMATCH=1`).
- **글로벌 태그** `vX.Y.Z` → 루트 `VERSION`과 대조.

## 예외
- **AP_Periph**(예: `AP-RTK_dual`, `AP-RTK_G5H`)는 자체 트랙. `build_ap.sh`가 펌웨어 안에 버전 문자열을 찍지는 않지만, `package_fw.sh`가 산출물 **파일 이름**을 `<board>-v<VERSION>.apj/.bin/.hex/_with_bl.hex` 로 붙인다(모든 주변장치가 같은 `AP_Periph` 타깃이라 맨 이름은 제품 구분이 안 됨). `release.sh` 는 이 이름을 그대로 자산으로 올린다.

## 현재 버전
| 보드 | 버전 |
|------|------|
| AF-F4_nano | 0.2.3 |
| AF-F4_T10_nano | 0.3.4 |
| AF-F7_mini | 0.2.3 |
| AF-H7E | 0.2.9 |
| AF-H7_nano | 0.2.3 |
| AD-ME1 | 0.1.0 |
| AP-RTK_dual | 0.1.0 (AP_Periph) |
| AP-RTK_X20D | 0.1.0 (AP_Periph · 보류 — `boards/AP-RTK_X20D/PORTING.md` 참조) |
| AP-RTK_G5H | 0.1.0 (AP_Periph · 설계 중 — mosaic-G5 P3H, SBF type 26. 회로 `41_Kicad/circuits/ap_rtk_g5h.py`) |

> 이전엔 루트 `VERSION` 하나가 전 보드에 일괄 적용돼, AF-H7E의 DFU 반복(→0.2.9)이 다른 보드까지 끌어올리는 문제가 있었다. 이제 보드별로 분리됨.
