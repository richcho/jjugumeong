# 기술 설계

이 문서는 코드 책임, 저장, 데이터, Web 빌드와 검증의 현재 기준을 설명합니다.
제품 방향은 `docs/jjugumeong_master_plan.md`를 따릅니다.

## 1. 기술 목표

- Godot 4.x와 GDScript로 개발
- 외부 에셋 없이도 기본 도형으로 핵심 루프 실행
- UI, 게임 상태, 저장과 화면 표현 분리
- iPad Safari/PWA를 주 모바일 검증 환경으로 사용
- V1 이전에는 서버와 온라인 기능을 추가하지 않음

## 2. 런타임 구조

| 구성요소 | 책임 | 소유하면 안 되는 것 |
| --- | --- | --- |
| `GameManager` | 자원, 강화, 지역, 이벤트 시간, 통계 | UI 노드와 파일 저장 구현 |
| `VisualProgression` | 강화 레벨을 외형 티어와 표시 이름으로 변환 | 자원 계산과 영구 상태 |
| `SaveManager` | JSON 저장, 백업, 검증, 마이그레이션 | 게임 규칙과 화면 표시 |
| `EventBus` | 상태 변경 신호 | 영구 상태 |
| `GatheringMouse` | 개별 쥐 이동과 운반 상태 | 전체 자원 잔액 |
| `WorldView` | 배경, 자원, 경로와 월드 효과 | 구매와 저장 규칙 |
| `GameUI` | 정보 표시, 버튼과 반응형 배치 | 게임 상태의 원본 |
| `DotActionView` | 점 기반 행동 렌더링, 터치 판정과 진행 상태 | 보상과 영구 완료 기록 |

상태 흐름:

```text
GatheringMouse 귀환
  → GameManager.collect_trip()
  → 자원·통계·지역 갱신
  → EventBus 신호
  → GameUI와 WorldView 다시 그리기
```

## 3. 데이터 구조

현재 데이터:

| 경로 | 내용 |
| --- | --- |
| `data/build.json` | 제품명, 표시 버전과 개발 단계의 단일 기준 |
| `data/stages/stages.json` | 지역, 해금 수치, 생산 보너스, 위험과 사건 |
| `data/mice/basic_mouse.json` | 기본 집쥐 능력의 확장 초안 |
| `data/resources/cheese.json` | 기본 자원 정의 |
| `data/events/initial_events.json` | 황금치즈 사건 정의 |
| `data/buildings/initial_buildings.json` | 후속 건물 식별자 |
| `data/research/research_branches.json` | 장기 연구 분기 목록 |

런타임은 식별자와 진행값을 저장하고, 표시 이름과 정적 속성은 데이터 파일에서
읽는 방향을 유지합니다. 데이터 필드가 추가되더라도 실제 사용 전에는
“구현됨”으로 문서화하지 않습니다.

## 4. 저장

| 항목 | 값 |
| --- | --- |
| 주 파일 | `user://savegame.json` |
| 백업 | `user://savegame.backup.json` |
| 임시 파일 | `user://savegame.tmp.json` |
| 현재 스키마 | 7 |

저장 순서:

1. 임시 파일에 전체 JSON 작성
2. 현재 정상 저장을 백업
3. 임시 파일을 주 파일로 교체
4. 로드 시 주 파일, 백업, 기본값 순으로 복구

저장 데이터 변경 규칙:

- 새 영구 필드를 추가하면 기본값을 정의
- 호환되지 않는 변경이면 `CURRENT_SCHEMA_VERSION` 증가
- `_migrate_data()`에 이전 버전 경로 추가
- 기존 저장, 손상 저장과 빈 저장 테스트
- changelog에 스키마 변경 기록

Web 세이브는 브라우저의 사이트 저장소에 의존합니다. 배포 주소 변경과 Safari
사이트 데이터 삭제는 별도 저장 공간으로 취급합니다.

Web에서는 `user://`의 IndexedDB 저장, `localStorage`, 소형 쿠키 백업을 함께
사용합니다.
화면 이탈, 앱 일시정지와 주요 강화 구매 때 즉시 저장하며, 파일 작성 뒤
`JavaScriptBridge.force_fs_sync()`로 영구 파일 시스템 동기화를 요청합니다.
정상 저장본 중 `last_saved_unix`가 최신인 데이터를 로드합니다.

스키마 2는 `selected_stage_index`, `unlocked_stage_ids`,
`completed_region_event_ids`, `next_region_event_unix`를 추가합니다. 스키마 1의
`current_stage_index`는 선택 지역으로 이관하고, 해금 목록은 누적 치즈와 지역
데이터에서 안전하게 재구성합니다.

스키마 3은 `completed_field_action_ids`와 `next_field_action_unix`를 추가합니다.
스키마 2 이하 저장은 완료한 현장 행동 없음, 대기 시간 0으로 이관합니다. 입력
진행은 일시적인 UI 상태이며 행동을 끝낸 뒤 `GameManager`가 보상과 완료 ID를
함께 저장합니다.

스키마 4는 지역 ID별 `region_progress`를 추가합니다. 각 상태는 행동 숙련도,
위험도, 안전 경로, 지역 표식과 마지막 선택을 가지며 스키마 3 이하 저장은
기본 위험도 2와 미개방 경로로 이관합니다.

스키마 5는 `nursery_level`, `nursery_pups`, `total_raised_pups`,
`next_pup_id`를 추가합니다. 각 새끼는 ID, 성장 완료 Unix 시각과 돌봄 횟수를
저장합니다. 스키마 4 이하 저장은 미건설 보육실과 빈 새끼 목록으로 이관합니다.
화면은 상태를 직접 바꾸지 않고 `GameManager`의 건설·등록·돌봄·합류 API만
호출합니다.

스키마 6은 `role_assignments`에 채집·탐험·건설 인구를 저장합니다. 스키마 5
이하 저장의 기존 쥐는 모두 채집 역할로 이관합니다. 로드 시 역할 합계를 전체
인구와 다시 맞추고 최소 채집쥐 1마리를 보장합니다. `WorldView`는 전체 인구가
아닌 `GameManager.get_gatherer_count()`로 실제 채집조를 구성합니다.

스키마 7은 `selected_hero_id`를 추가합니다. 스키마 6 이하 저장은 선택 없음으로
이관하고, 저장된 ID가 `data/mice/heroes.json`에 없으면 선택 없음으로
복구합니다. 후보 데이터는 표현과 설명을 담당하고, 해금·확정·효과 계산은
`GameManager`가 담당합니다.

스키마 8은 `hero_bond_level`과 `next_hero_mission_unix`를 추가합니다. 스키마 7
이하 저장은 유대 Lv.0과 즉시 임무 가능 상태로 이관합니다. 선택 영웅이 없으면
두 값도 0으로 정리하며 유대는 0~3으로 제한합니다. `HeroBondView`는 점 배치,
입력 판정과 실수만 담당하고, 보상·대기 시간·유대 효과와 저장은
`GameManager`가 단일 책임으로 처리합니다.

스키마 9는 `save_revision`을 추가합니다. 저장할 때마다 revision을 증가시키고
여러 저장본을 비교할 때 Unix 초보다 먼저 사용합니다. Web은 `localStorage`
현재본과 직전 정상본, URI 인코딩한 조각 쿠키 복구본을 유지합니다. 파일
현재본·파일 백업까지 포함해 가장 높은 revision의 정상 JSON을 불러옵니다.
기존 단일 localStorage 키와 단일 쿠키도 읽기 호환을 유지합니다.

Web 저장은 origin 단위이므로 `chatgpt.site` 주소와 별도 사용자 도메인의
저장소는 자동 공유되지 않습니다. 브라우저 사이트 데이터 삭제, 비공개 탐색,
저장 차단 정책에서도 데이터 유지가 보장되지 않으므로 UI는 실제로 성공한 저장
경로를 표시합니다.

## 5. 화면과 반응형 규칙

- 논리 기준 해상도: 1280×720
- Stretch: `canvas_items`
- Aspect: `expand`
- 가로형 우선이지만 세로형에서 화면을 자르지 않음
- 1000px 미만 논리 폭에서는 하단 버튼을 2열로 배치
- 상·하단 패널은 화면 가장자리에서 안전 여백 확보
- 월드의 구멍과 자원은 뷰포트 비율로 배치
- 크기 변경 시 쥐 이동 경로 갱신

`GatheringMouse`는 V0.4.5부터 경로 진행과 별도로 현재 속도, 탐색 대기,
행동 상태, 방향 전환, 자세와 꼬리 지연을 관리합니다. `WorldView`는 여전히
경로와 보이는 작업조만 구성하고, `GameManager`는 이동 표현을 알지 않은 채
보상과 강화 수치를 계산합니다. 꼬리와 몸은 기존 스프라이트의 겹치는 영역을
분리해 그리므로 별도 에셋이 없어도 실행됩니다.

iPad Web 셸은 다음을 보장해야 합니다.

- `viewport-fit=cover`
- Safari 동적 뷰포트 단위 사용
- 캔버스를 보이는 화면에 고정
- 스크롤과 확대 제스처로 인한 화면 이탈 방지
- 홈 화면 PWA와 일반 Safari 양쪽 확인
- 새 서비스 워커는 즉시 활성화하고 열린 화면을 최신 버전으로 한 번 갱신

## 6. 한글과 에셋

Godot Web 기본 대체 글꼴에 의존하지 않습니다.
`assets/fonts/NotoSansKR-Full.ttf`를 프로젝트 기본 글꼴과 직접 그리기 텍스트에
사용합니다.

서브셋 글꼴에 새 문자가 없을 수 있으므로, 사용자에게 보이는 한국어 문구를
추가할 때 glyph 검증 테스트도 갱신합니다. 이모지는 플랫폼별 렌더링 차이가
크므로 핵심 UI 정보에는 사용하지 않습니다.

## 7. Web/PWA 빌드

```text
Godot Web export
  → builds/web
  → tools/prepare-web-build.mjs
     - public/game 복사
     - 불필요 import 파일 제거
     - WASM gzip
     - Safari viewport 보정
     - 서비스 워커 캐시 경로 보정
     - 빌드 버전 메타데이터 삽입
  → tools/verify-web-build.mjs
     - viewport, PWA, 서비스 워커와 gzip WASM 검사
  → Vinext build
  → dist
  → Sites 배포
```

`export_presets.cfg`는 호스팅 산출물, `node_modules`, `dist`, `public`을 Godot
PCK에 다시 포함하지 않아야 합니다.

## 8. 검증 기준

기본 검증:

```bash
godot4 --path . --headless --import
godot4 --path . --headless tests/test_runner.tscn
godot4 --path . --headless --export-release Web builds/web/index.html
npm run prepare:game
npm run verify:game
npm run build
git diff --check
```

기능 위험에 맞춰 다음을 추가합니다.

- 저장 변경: 이전·손상·백업 저장 테스트
- UI 변경: 대표 iPad 가로·세로 화면 확인
- 폰트 변경: 현재 한국어 문자의 glyph 포함 확인
- Web 변경: 새 Safari 탭, PWA 재실행, 서비스 워커 갱신
- 밸런스 변경: 지역 도달 시간 비교

## 9. 확장 규칙

- 쥐 외형 티어는 능력 계산과 분리해 유지하되, 화면 표현은 전용 아트가 준비된
  단계만 연결
- 지역 배경은 스테이지 ID를 기준으로 선택
- 사건은 결과를 직접 UI에 넣지 않고 게임 상태 계층을 거침
- 건물, 직업과 연구는 같은 자원 원장과 EventBus를 사용
- 저장 가능한 Dictionary에 Godot 노드나 리소스 객체를 넣지 않음
- 네이티브 클래스의 메서드·프로퍼티 이름과 사용자 정의 이름 충돌 방지
- 새 기능은 headless 실행을 막는 플랫폼 전용 호출을 격리

## 10. 알려진 기술 과제

| 상태 | 과제 | 처리 방향 |
| --- | --- | --- |
| 구현됨 | 시각 단계 매핑 | `VisualProgression`이 티어와 표시 이름을 계산, 절차적 오버레이는 V0.3.1에서 제거 |
| 다음 | 지역 배경 책임 | `WorldView`를 지역 장면 구성 요소로 분리 |
| 구현됨 | 다음 보상 계산 | `GameManager.get_next_reward_summary()` 상태 API 사용 |
| 구현됨 | 지역 선택 저장 | 스키마 2의 `unlocked_stage_ids`와 현재 선택 지역 사용 |
| 결정 대기 | 전체 한글 글꼴 크기 | 문구 증가 시 서브셋 재생성 또는 전체 폰트 전환 비교 |
