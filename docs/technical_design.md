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
| 현재 스키마 | 1 |

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

## 5. 화면과 반응형 규칙

- 논리 기준 해상도: 1280×720
- Stretch: `canvas_items`
- Aspect: `expand`
- 가로형 우선이지만 세로형에서 화면을 자르지 않음
- 1000px 미만 논리 폭에서는 하단 버튼을 2열로 배치
- 상·하단 패널은 화면 가장자리에서 안전 여백 확보
- 월드의 구멍과 자원은 뷰포트 비율로 배치
- 크기 변경 시 쥐 이동 경로 갱신

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

- 쥐 외형은 능력 계산과 분리된 표현 단계로 매핑
- 지역 배경은 스테이지 ID를 기준으로 선택
- 사건은 결과를 직접 UI에 넣지 않고 게임 상태 계층을 거침
- 건물, 직업과 연구는 같은 자원 원장과 EventBus를 사용
- 저장 가능한 Dictionary에 Godot 노드나 리소스 객체를 넣지 않음
- 네이티브 클래스의 메서드·프로퍼티 이름과 사용자 정의 이름 충돌 방지
- 새 기능은 headless 실행을 막는 플랫폼 전용 호출을 격리

## 10. 알려진 기술 과제

| 상태 | 과제 | 처리 방향 |
| --- | --- | --- |
| 구현됨 | 시각 단계 매핑 | `VisualProgression`이 속도·운반·쥐구멍 티어를 계산 |
| 다음 | 지역 배경 책임 | `WorldView`를 지역 장면 구성 요소로 분리 |
| 구현됨 | 다음 보상 계산 | `GameManager.get_next_reward_summary()` 상태 API 사용 |
| 결정 대기 | 지역 선택 저장 | V0.3에서 `unlocked_stage_ids`와 현재 선택 지역 검토 |
| 결정 대기 | 전체 한글 글꼴 크기 | 문구 증가 시 서브셋 재생성 또는 전체 폰트 전환 비교 |
