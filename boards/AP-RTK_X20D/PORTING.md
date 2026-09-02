# AP-RTK X20D — ArduPilot 드라이버 포팅 계획

> 조사일 2026-09-02 · 대상 submodule `firmware/ardupilot` = ArduPilot 4.6.3 (`92b0cd78`, 2025-11-11)

## 0. 한 줄 요약

**ZED-X20D는 하드웨어로는 UM982의 상위 호환이지만, ArduPilot이 아직 읽지 못한다.**
보드 설계보다 이 드라이버가 임계경로다. PCB를 뜨기 전에 §4를 먼저 끝낸다.

> **2026-09-02 추가 — 요건 "지금 당장 구매"가 확정되어 X20D는 보류.** 재고 0(2027-02 입고).
> 즉시 구매 가능한 비중국 대안 비교는 **§3-3**. 현재 유력 = Septentrio mosaic-H.

## 1. 왜 X20D인가

목표는 "기체에 안테나 2개 = 헤딩", 즉 AP-RTK dual(UM982)이 하는 일을 u-blox로
하는 것. u-blox에서 이걸 **한 칩**으로 하는 제품은 X20D 하나뿐이다.

| | UM982 (AP-RTK dual) | **ZED-X20D** | ZED-F9P × 2 |
|---|---|---|---|
| 수신기 수 | 1 | **1** | 2 |
| 대역 | L1/L2 | **L1/L2/L5/L6 + L-band** | L1/L2 |
| 헤딩 | 네이티브 | 네이티브 (정지·저속 포함) | 무빙베이스라인 |
| 위치 정확도 / 레이트 | — | 0.6 cm / 25 Hz | — |
| 보정 서비스 | — | RTK · PPP-RTK · PPP · Galileo HAS | RTK |
| ArduPilot | `GPS_TYPE 25` 네이티브 | **없음** | `GPS_TYPE 17/18` 성숙 |
| 보드 면적·전력·BOM | 기준 | 기준 | **약 2배** |

F9P×2 기각 사유: 비용·면적·전력이 2배인데 성능은 UM982와 동급(L1/L2). 후속
제품으로서 퇴보다.

부품 조달: 2026-03-05 발표. ArduSimple `simpleRTK 4 Dual`(X20D 탑재)이
2026-04-20 출하 개시, €299 → 평가보드는 지금 확보 가능.

## 2. 현황 — 레포에서 직접 확인한 사실

| 확인 항목 | 결과 |
|---|---|
| 우리 submodule 4.6.3 | X20 문자열 **0건** |
| upstream master `AP_GPS_UBLOX.h` | `UBLOX_X20 = 0x84` **enum 선언만 존재** |
| upstream master `_hardware_generation = UBLOX_X20` 대입 | **어디에도 없음** → 자동 판별 미배선 |
| upstream master `supports_F9_config()` / lag 테이블 | X20 포함됨 (`AP_GPS_UBLOX_CFGV2_ENABLED` 가드) |
| MON-VER 하드웨어 세대 판별 | `"00190000"`(F9), `"000A0000"`(M10) **둘뿐** |
| `AP_GPS.h`의 `GPS_TYPE` 목록 | 25=UM982, 26=Septentrio 듀얼안테나. **u-blox 듀얼안테나 타입 없음** |
| Issue #31982 (X20P 지원 요청, 2026-01-22) | **Open · PR 없음 · 코멘트 없음** |
| upstream hwdef `ARK_X20*` | 없음 (`ARK_RTK_GPS`만) |

정리: upstream에 있는 건 **신규 config 프레임워크(CFGV2)에 딸려 들어간 껍데기**다.
X20을 꽂아도 세대 판별이 안 돼 unknown generation으로 떨어진다.

## 3. 헤딩 출력 경로 — 최대 분기점

- X20D의 헤딩 전용 메시지는 신규 **`UBX-NAV-DAHEADING`**
- 동시에 기존 **`UBX-NAV-RELPOSNED`도 낸다는 정보가 있으나 미확인** ← **이게 일정을 가른다**

| 시나리오 | 작업량 | 내용 |
|---|---|---|
| **A. RELPOSNED 나옴** | 작음 (수일) | ArduPilot의 기존 무빙베이스라인 수신 경로 재사용. `AP_GPS_UBLOX.cpp`의 `MSG_RELPOSNED` 핸들러가 `role == GPS_ROLE_MB_ROVER`일 때만 처리하므로, 단일 모듈용 role/타입만 추가하면 됨 |
| **B. DAHEADING 전용** | 큼 | 신규 메시지 구조체 + 파서 + `GPS_TYPE` 신규 값 + CFGV2 키 세트까지 추가 |

`hwdef.dat`에서 `GPS_MOVING_BASELINE 1`을 켜 둔 이유가 A 시나리오 대비다.
B로 확정되면 꺼서 플래시를 회수한다.

## 3-1. 부품 조달 현황 (2026-09-02 실사)

**칩 단품은 지금 못 산다. 평가보드는 지금 살 수 있다.**

| | ZED-X20D 칩 단품 | simpleRTK 4 Dual (평가보드) |
|---|---|---|
| 재고 | **0** (DigiKey 글로벌·중국 동일) | **있음** |
| 입고 예정 | **2027-02-16**, 250개 | 즉시 |
| 원장 리드타임 | **20주** | — |
| 가격 | ¥1,891 / 개 (CT, 1+)<br>¥1,545 / 개 (TR, MOQ 250 = ¥386k) | €299 |
| 중국 배송 | 가능 (7–10 영업일, 300元↑ 순펑 무료) | 가능 (2–5일, 스페인 발송) |

- 중국 **로컬 소싱은 아직 없다.** 1688·화창베이·LCSC에서 유효한 리스팅을 찾지 못했다
  (LCSC의 u-blox 취급 여부 자체는 확인 실패 — 없다고 단정한 것 아님).
  정식 유통 재고가 전 세계 0인 신제품이라 당연한 결과다.
- ⚠️ 그래서 화창베이·1688에 "현물 있음"으로 뜨는 물건이 있다면 **리마킹·가짜를 의심**해야 한다.
  정식 채널 0 / 리드타임 20주인 부품에 로컬 현물이 존재할 개연성이 낮다.
- 구매 **채널**은 요건과 무관하다 — 중국에서 사도 된다(2026-09-02 사용자 확인). 요건은 부품
  자체(제조사·원산지)에 걸린다. 다만 위조품 리스크는 요건과 별개의 품질 문제라 위 경고는 그대로 유효.

**일정에 주는 의미 — 칩 공급은 이 프로젝트를 막지 않는다.**
지금 발주해도 20주 뒤(2027-01경)에나 칩이 온다. 그런데 §4의 드라이버 작업도 어차피 그만큼
걸린다. **평가보드 1장으로 드라이버를 먼저 끝내 두면 칩이 풀릴 때 바로 양산에 들어간다.**
순서를 뒤집어(PCB 먼저) 진행하면 칩도 없고 드라이버도 없는 상태로 대기하게 된다.

## 3-2. 원산지·공급망 요건 — 이 프로젝트의 진짜 동기 (2026-09-02 확인)

이 보드를 만드는 이유는 성능이 아니라 **UM982(Unicore, 북경)를 부품 원산지 요건 때문에 배제**해야
해서다. 그래서 "u-blox = 스위스"로 끝나지 않는다. 아래가 전부 검토 대상이다.

| 항목 | 현황 | 해야 할 것 |
|---|---|---|
| **ZED-X20D 모듈 COO** | u-blox는 팹리스. 모듈 조립은 EMS(Flex) 위탁으로 과거 오스트리아 Althofen 중심. **현행 ZED 시리즈 COO는 "출하 시 결정"(Future Electronics 명시)이고 유통 리스팅에 China 표기 사례가 있다** | 규정이 **제조국(COO)**을 본다면: u-blox 한국지사/대리점에 X20D 생산지 서면 확인 + 로트별 COO 확인서. 규정이 **제조사 국적(브랜드)**만 본다면 u-blox(스위스)로 충족 — 어느 쪽인지 확정 필요 |
| 조달 채널 | **요건과 무관 — 중국 구매 가능**(사용자 확인). 정식: DigiKey(중국 직배송 7–10일 / 수원 현지지원)·Mouser·Avnet. 로컬 현물(화창베이·1688)은 현재 없음 | 채널은 자유. 단 품질 관점에서 정식 재고 0인 동안 로컬 "현물"은 위조 의심 — CoC·로트 서류 나오는 곳으로 |
| 캐리어보드 BOM | AP-RTK dual = CUAV C-RTK2-HP 클론 설계. **BOM 파일이 워크스페이스에 없음** | BOM 확보 → 전 항목에 원산지 열 추가. STM32F412(ST)·RM3100(PNI, 미국)은 무난. CAN 트랜시버·레귤레이터·LNA/SAW·수정·커넥터 등 나머지 전수 |
| PCB 제조·조립 | 미확인 | 규정이 조립국까지 보면 조립처 변경이 필요할 수 있음 |
| 안테나 | 멀티밴드 2개 필요. 드론용 저가 안테나는 중국산(Beitian 등)이 대부분 | Tallysman(캐나다)·Taoglas(아일랜드)·u-blox ANN-MB 계열 등으로 대체 검토 |
| 평가보드 | ArduSimple(스페인) — 개발용이라 무관 | — |

**규정 확인 필요**: 설계국·제조국·조립국 중 무엇을 기준으로 삼는지에 따라 위 표의 범위가
달라진다. 확정 전에는 BOM 검토 범위를 넓게 잡는다.

## 3-3. 요건 확정 후 재판정 — "제조사 비중국 + 지금 당장 구매" (2026-09-02)

요건이 두 가지로 확정됐다: ① **제조사가 중국 회사인지만** 본다(제조국·구매 채널 무관),
② **지금 당장 살 수 있어야** 한다. → **X20D는 ②에서 탈락**(전 세계 재고 0, 2027-02 입고).

지금 살 수 있는 비중국 듀얼안테나 헤딩 후보(DigiKey 실사, 2026-09-02):

| | **Septentrio mosaic-H** | **u-blox ZED-F9P + ZED-F9H** | ZED-X20D (참고) |
|---|---|---|---|
| 제조사 | 벨기에 | 스위스 | 스위스 |
| 칩 수 / 안테나 | **1칩** 2안테나 | **2칩** 2안테나 | 1칩 2안테나 |
| ArduPilot | ✅ `GPS_TYPE 26` 네이티브 — AP_Periph에서 UM982(25)와 **완전히 같은 경로**(`gps.get_RelPosHeading()`) | ✅ `GPS_TYPE 17/18` 네이티브 | ❌ 드라이버 없음 |
| upstream AP_Periph 선례 | `HitecMosaic`(F303, SBF type 10 — 헤딩은 26으로 바꾸면 됨) | **없음** — GPS 2대 온보드 periph 보드 0개. 2인스턴스 MB를 한 노드에서 돌리는 건 우리가 첫 검증 | 없음 |
| 재고 (DigiKey) | **48개** (PN 410548) | F9P-04B **6,586** / F9H-01B **175** | 0 |
| 단가 (1+) | **≈ $1,080–1,100** | $127 + $111 ≈ **$238/세트** | $228 |
| 대역 | L1/L2 (GPS L1/L2, GAL E1/E5b, GLO L1/L2, BDS B1/B2/B3) | L1/L2 | L1/L2/L5/L6 |
| 헤딩 레이트 | RTK+attitude 20 Hz | RELPOSNED ~5–8 Hz 급 | 25 Hz |
| 패키지 | 31×31 mm LGA-239, 6.8 g, 3.3 V, 0.6 W typ | 22×17 mm LGA-54 ×2 | 22×17 LGA-54 |
| AP-RTK dual 기본판 유용 | 부분 — 수신기 풋프린트·전원 재설계, MCU·RM3100·CAN 프레임은 유지 | 불가 — UART 2개 + 모듈 간 RTCM 배선(`GPS_DRV_OPTIONS` bit0 = UART2 직결) + 면적 2배 | 부분 |
| 리스크 | 단가. 재고 48개라 양산 물량은 리드타임 확인 필요 | 한 노드 2×u-blox MB **미검증**. 대안은 노드 2개(type 22/23, upstream 검증됨)인데 제품이 2박스가 됨 | 드라이버 + 2027-02 |

**판정**
- **mosaic-H**: 세 요건(비중국·즉시 구매·1칩 듀얼안테나)을 전부 만족하고 펌웨어 경로가 UM982와
  동일해 개발 리스크가 가장 낮다. 대가는 단가 ≈ $1,080.
- **F9P+F9H**: 단가 1/4이지만 2칩 재설계 + AP_Periph 2인스턴스 통합을 우리가 처음 검증해야 한다.
- **X20D**: 2027년 후속 후보로 보류. 이 문서의 §1–§4는 그 시점에 다시 쓴다.

제외: Hemisphere(Unistrong→BDStar 중국 소유), Unicore/Allystar/Quectel(중국), ZED-X20P×2(드라이버 없음).

## 3-4. 비중국 듀얼안테나 후보 전수 — u-blox 밖까지 (2026-09-02)

**ArduPilot 헤딩 경로 사실(4.6.3 로컬 확인):**
- 헤딩을 파싱하는 드라이버: **UBLOX**(RELPOSNED, MB) · **NMEA**(`$xxHDT`/`THS` 범용 + Unicore `UNIHEADINGA`) · **SBF**(AttEuler/AuxAntPositions, `GPS_TYPE 26`).
  **GSOF(11)·NOVA(15)·SBP(8)는 헤딩 없음** → Trimble/NovAtel은 NMEA HDT로 써야 한다.
- AP_Periph(DroneCAN)는 두 메시지로 헤딩을 보낸다: MB 계열(u-blox·Unicore)은 `ardupilot.gnss.RelPosHeading`,
  그 외(SBF·NMEA HDT)는 `ardupilot.gnss.Heading`(`gps.cpp:218`, `gps_yaw_deg()`). FC는 `AP_GPS_DroneCAN::handle_heading_msg`로 받는다.
  → **SBF·NMEA-HDT 모듈도 AP-RTK dual 펌웨어 구조(AP_Periph) 그대로 헤딩이 나간다.**

| 후보 | 제조사 (국적) | 형태 / 크기 | 대역 | AP 헤딩 경로 | 재고 · 가격 (2026-09-02) | 비고 |
|---|---|---|---|---|---|---|
| **Septentrio mosaic-G5 P3H** ★ | 벨기에 | LGA **22.8×16.4×2.4 mm**, 2.2 g | 듀얼안테나 헤딩 모드 = **트리플밴드** L1/L2/L5 (E6·B3I·GLO L3 는 단일안테나 모드에서만 — P3H 데이터시트) | SBF `26` → `gnss.Heading` | Septentrio P/N **410502** (HW manual §3.1.1.1: P1=410461, P3=410501, **P3H=410502**). DigiKey P3H 페이지에는 410501 $294.86 / 96개가 걸려 있으나 Septentrio 표에서 410501 = P3(단일안테나) → **발주는 410502로 지정·확인** (DigiKey EU 검색 노출가 €260.98, 재고 미확인); EVK mosaic-go G5 P3H 410538 $487.50 (19개); ArduSimple simpleRTK4 Heading €499 | 0.15°@1 m, 20 Hz, 789ch, AIM+ 재밍/스푸핑 탐지. 양산 중. **mosaic-H의 ¼ 가격·½ 면적**. ⚠️ **raw 측정 출력은 P3 전용 — P3H는 로버 전용**(기지국/RTCM 송출 불가, 데이터시트 2025-05) |
| Septentrio mosaic-H | 벨기에 | LGA-239 31×31 mm, 6.8 g | L1/L2 | SBF `26` → `gnss.Heading` | DigiKey 410548 48개 @ ≈$1,080 | 검증 이력 김(HitecMosaic 등). 비쌈 |
| u-blox ZED-F9P + ZED-F9H | 스위스 | LGA-54 22×17 ×**2** | L1/L2 | UBLOX `17/18` → `RelPosHeading` | 6,586 / 175 @ $127 + $111 | 2칩. 한 AP_Periph 노드에 u-blox 2대 온보드 선례 0 |
| Hemisphere Vega 28 | **CNH Industrial** (네덜란드 법인·영국/미국) — 2023-10-12 Unistrong(중국)에서 인수 완료 → **비중국** | 보드 45×71 mm, 28핀 헤더 | 멀티주파수 + L-band Atlas | NMEA `$GPHDT` → `GPS_TYPE 5` → `gnss.Heading` | 견적 (NavtechGPS·Canal Geomatics) | 앞선 §3-3의 "Hemisphere=중국 소유"는 **정정** — 2023년까지 얘기. 보드형이라 도터보드 실장. 가격 미공개 |
| Trimble BD992 | 미국 | OEM 보드 | 전대역 + RTX | NMEA HDT → `5` (GSOF는 헤딩 없음) | 견적, 5–10일 (Canal) | 측량급 고가 |
| NovAtel OEM7720 | 캐나다 (Hexagon) | 71×46×11 mm, 35 g | 전대역 | NMEA `GPHDT` → `5` (NOVA는 헤딩 없음) | 견적 | 고가. 시리얼 5·CAN 2·이더넷 |
| Locosys RTK-DUAL | **대만** | 27×20×5.4 mm | L1/L5 | NMEA HDT(추정) → `5` | 미공개 (직판 / APC) | **5 Hz 한계.** 대만을 요건상 어떻게 볼지 결정 필요. 내부 칩셋 미확인 — Locosys는 Airoha(대만)·**Allystar(중국)**·MediaTek 혼용이라 이 모델 칩 확인 필수 |
| ZED-X20D | 스위스 | LGA-54 22×17 | L1/L2/L5/L6 | 없음 | 0 (2027-02) | 보류 |

제외: Unicore·Allystar·Quectel·Tersus·ComNav·Bynav(중국). Swift(SBP 헤딩 없음, HW 축소). STMicro Teseo(듀얼안테나 없음). Furuno·Topcon·Javad(모듈급 아님·AP 미지원·고가).

**판정 갱신 — 유력 = mosaic-G5 P3H.** 세 요건(비중국·즉시 구매·1칩 2안테나)에 더해 가격($295)·크기(22.8×16.4)·삼중대역까지 UM982 대체로 가장 근접하다.
mosaic-H보다 최근 제품이라 필드 이력이 짧다는 것만 감안. SBF는 동일 프로토콜이라 `GPS_TYPE 26` 그대로 붙을 가능성이 높지만 **EVK(410538, $487.50)로 실측 후 확정**.

## 3-5. mosaic-G5 P3H ↔ UM982 전 항목 대조 (데이터시트 기준: Septentrio 2025-05 / Unicore 2022-08)

원본 PDF: `39_gitNovaX/docs/rtk-gnss/AP-RTK_G5H/datasheets/Septentrio_mosaic-G5_P3_P3H_Datasheet.pdf`, `docs/rtk-gnss/AP-RTK_dual/Unicore_UM982_Datasheet.pdf`

| 항목 | UM982 (현행 AP-RTK dual) | mosaic-G5 P3H | 판정 |
|---|---|---|---|
| 제조사 | Unicore, 북경 (Nebulas-IV 22 nm) | Septentrio, 벨기에 | ✅ 요건 |
| 채널 | 1408 | 789 | 숫자만 다름 (아키텍처 차) |
| 대역 | GPS L1/L2/L5 · GAL E1/E5a/E5b · BDS B1I/B2I/B3I · GLO L1/L2 · QZSS L1/L2/L5 · SBAS | GPS L1C/A·L1C·L2C·L2P·L5 · GAL E1/E5a/E5b/**E6** · BDS B1I/**B1C**/B2a/B2I/**B2b**/B3I · GLO L1/L2/**L3** · QZSS L1/L2/L5/L6* | P3H 우위 (신호 더 많음). 단, 듀얼안테나 헤딩 모드는 트리플밴드(L1/L2/L5) — E6/L3 는 단일안테나 모드 전용. SBAS는 P3H 시트 미기재 |
| 슬레이브 안테나 대역 | 마스터보다 축소(L5 없음 — 카탈로그 기준) | 시트에 안테나별 구분 없음 | 확인 필요 |
| 단독 측위 (RMS) | H 1.5 m / V 2.5 m | H 1.2 m / V 1.9 m | P3H |
| DGNSS | H 0.4 m / V 0.8 m | H 0.4 m / V 0.7 m | 동급 |
| RTK | H 0.8 cm+1 ppm / V 1.5 cm+1 ppm | **H 0.6 cm+0.5 ppm / V 1 cm+1 ppm** | P3H |
| RTK 초기화 | <5 s typ, 신뢰도 >99.9%, RTK KEEP 10분 | 7 s | UM982 약간 빠름 |
| 헤딩 정확도 | **0.2° @1 m** (INSTANT HEADING 단일 에폭) | **0.15° @1 m · 0.03° @5 m**; pitch/roll 0.25°/0.05° | P3H |
| 속도 정확도 | 0.03 m/s | 3 cm/s | 동일 |
| 출력 레이트 | 20 Hz (위치+헤딩 동시) | 위치 20 Hz, 지연 <10 ms; 헤딩 레이트 별도 미기재 | 동급 (P3H 헤딩 레이트 실측) |
| TTFF | cold <30 s · warm <10 s · 재획득 <1 s | cold <35 s · warm <10 s · 재획득 1 s | 동급 |
| 시각 | 20 ns RMS | PPS 분해능 1.4 ns, 이벤트 <3 ns | P3H |
| PPS / 이벤트 | PPS 있음(핀맵); 이벤트 — 매뉴얼 확인 | **PPS ×2, 이벤트 마커 ×2** | P3H |
| 보정 입력 | RTCM v3.x | RTCM v3.x (MSM 포함) | 동일 |
| **기지국/원시 데이터 출력** | 지원 (Unicore 바이너리 OBS, BASE 모드 — 매뉴얼) | **❌ P3H는 raw 미출력(P3 전용) → 로버 전용** | ⚠️ 유일한 기능 결손. AP-RTK dual은 로버 제품이라 실사용엔 영향 없음 |
| 프로토콜 | NMEA-0183, Unicore ASCII/바이너리 | SBF, NMEA 0183 (2.3/3.03/4.0) | — |
| 보정 서비스 | — | Galileo HAS(SW 롤아웃 예정), OSNMA 인증 | P3H |
| 내간섭 | "advanced anti-interference" (미상세) | AIM+ 재밍/스푸핑 탐지·자동완화, APME+, LOCK+, IONO+, RAIM+ | P3H (문서화된 기능) |
| UART | **3** (LV-TTL) | **2** (LV-TTL, 4 Mbps) | 제품은 1개만 씀 → 무관 |
| 기타 I/F | I2C*, SPI*, CAN*(UART3 공유, *특정 FW) | USB 2.0 HS, GPIO 2 | MCU가 CAN 담당 → 무관 |
| 전원 | 3.3–5 V, **600 mW** typ, 리플 100 mV p-p | 3.0–5.5 V, **0.6 W typ / 0.785 W max** | 동일 |
| 안테나 급전 | 미기재 | 내장 전류제한 150 mA, 프리앰프 15–35 dB(DA) | 기존 안테나 LNA 이득 확인 |
| 크기 / 무게 | **16×21×2.6 mm**, 48-LGA, 1.82 g | **22.8×16.4×2.4 mm**, LGA, 2.2 g | 면적 +11% (336→374 mm²), 풋프린트 다름 → 재배선 |
| 온도 | −40~85 / 보관 −55~95 | −40~85 / 보관 −55~85 | 동급 |
| 환경 인증 | GJB150.16-2009, MIL-STD-810F | IEC 60721-3-5 5M3, MIL-STD-810H 514.8/516.8, CE/FCC/RoHS/WEEE/ISED | 동급 |
| ArduPilot | `GPS_TYPE 25` (AGRICA+UNIHEADINGA) → `RelPosHeading` | `GPS_TYPE 26` (SBF) → `gnss.Heading` | 둘 다 네이티브, AP_Periph 그대로 |
| 가격 · 재고 | (중국산 — 대상 외) | P/N 410502; DigiKey P3H 페이지 표시가 $294.86·96개(410501=P3 번호와 혼재 → 발주 시 410502 확인), EU 노출가 €260.98 | — |

**결론:** 기능·성능은 P3H가 전 항목 동급 이상(헤딩 0.15° vs 0.2°, RTK 0.6 cm vs 0.8 cm, 헤딩 모드 트리플밴드 L1/L2/L5, AIM+).
결손은 **기지국/raw 출력 불가** 하나뿐이며 로버 제품엔 무관. 설계 변경은 풋프린트(22.8×16.4 LGA)와 안테나 LNA 이득 확인.

## 4. 착수 순서 (PCB보다 먼저)

0. **요건 기준 확정 → (필요 시) X20D COO 서면 확인** — 규정이 제조사 국적만 보면 u-blox로 끝.
   제조국(COO)을 보면 u-blox 한국지사/대리점에 생산지·로트별 COO 확인서를 먼저 묻는다(§3-2).
   1과 병행하되, **COO가 기준인데 답이 부정이면 2 이후를 진행하지 않는다** — 드라이버를
   포팅해도 요건 미달이면 양산에 못 쓴다
1. **평가보드 확보** — ArduSimple simpleRTK 4 Dual(€299) 1장. **재고 있음, 2–5일 배송**(§3-1).
   이 1장이 전체 일정을 결정한다. 멀티밴드 안테나 2개는 미포함이므로 같이 준비할 것
2. **인터페이스 설명서 입수 후 §3 판정** — DAHEADING / RELPOSNED 실측. `pyubx2` 등으로 원시 UBX 덤프
3. **submodule 상향 판단** — 4.6.3에는 CFGV2 프레임워크와 `UBLOX_X20` enum조차 없다.
   (a) upstream 최신으로 상향, 또는 (b) CFGV2 + X20 스캐폴딩을 4.6.3으로 백포트.
   AP-RTK dual·FC 보드 전체가 같은 submodule을 공유하므로 **상향은 전 보드 회귀 검증을 동반**한다 — 비용 큼
4. **드라이버 작성** — MON-VER 세대 판별 추가 → CFGV2 키 세트 → 헤딩 경로(A 또는 B) → `GPS_TYPE` 신규 값
5. **`patches/ardupilot/`에 패치로 등록** — 이 레포의 확립된 관행. 현재 3개 운용 중
   (`0001-novax-software-dfu-board`, `0002-signing-timestamp-throttle`, `0003-m10-lna-mode`).
   `scripts/apply_ap_patches.sh`가 멱등 적용
6. **upstream 기여 검토** — Issue #31982가 열려 있고 PR이 없다. 우리가 먼저 낼 수 있다

## 5. 하드웨어 미확인 항목

`hwdef.dat`는 AP-RTK dual 기본판을 그대로 유용했다. 아래는 **검증 안 된 상속분**:

- **RM3100 Z축 반전 (`AP_RM3100_REVERSAL_MASK 4`)** — AP-RTK dual PCB에서 실측된 값.
  부품 배치가 같다는 가정으로 물려받았을 뿐이다. 초도품에서 4개 방위(60/150/230/300°)
  원시 X/Y/Z 로깅으로 재확인할 것
- **USART2 보드레이트 / DMA** — X20D는 all-band 25 Hz로 UM982보다 스트림이 무겁다.
  PCB 확정 전 통합 매뉴얼로 확인
- **전원·RF 예산** — 레일·소비전류·2번 안테나 경로 모두 UM982 기준. X20D 데이터시트로 재산정
- **USB-C** — AP-RTK dual은 USB DFU가 없다. X20D 설정·펌웨어 업데이트에 USB가 필요한지 확인

## 6. 참고

- [ZED-X20D 제품 페이지](https://www.u-blox.com/en/product/zed-x20d-module)
- [ZED-X20D Product Summary (PDF)](https://content.u-blox.com/sites/default/files/documents/ZED-X20D_ProductSummary_UBXDOC-304424225-20335.pdf)
- [ArduSimple — Meet the new ZED-X20D](https://www.ardusimple.com/meet-the-new-u-blox-zed-x20d/)
- [ArduPilot Issue #31982 — Add support for ZED-X20P](https://github.com/ArduPilot/ardupilot/issues/31982)
- [ublox_dgnss (ROS2, X20P/F9P UBX 참고 구현)](https://github.com/aussierobots/ublox_dgnss)
- 형제 보드: `boards/AP-RTK_dual/` (UM982, 출하 중, v0.1.0)
