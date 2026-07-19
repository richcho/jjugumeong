# 쥐구멍 (JJUGUMEONG)

> 작은 쥐구멍 하나에서 시작해 세상 모든 쥐의 문명을 만든다.

Godot 4와 GDScript로 만드는 2D 방치형 문명 성장 게임입니다. 한 마리의 집쥐가
치즈를 나르는 작은 생존 이야기에서 시작해, 쥐구멍을 지하 마을과 세계 문명으로
성장시키는 것이 장기 목표입니다.

## 현재 상태

- 현재 버전: `r4 0.4.3` (`V0.4 Alpha`)
- 주 테스트 환경: iPad Safari 및 홈 화면 PWA
- 구현 완료: 자동 왕복, 치즈 수집, 4종 업그레이드, 5개 지역, 황금치즈,
  클릭 부스트, 저장·오프라인 보상, 지역별 배경, 지역 재방문과 2선택 사건
- 현재 개발: 첫 영웅의 전용 점 임무와 유대 성장

실기기 결과는
[`docs/testing/ipad_v0.2_checklist.md`](docs/testing/ipad_v0.2_checklist.md)에
기기 정보, 절차와 판정을 기록합니다.

V0.2 보이는 성장은 사용자 iPad 실행 확인을 마쳤습니다. V0.3 Alpha에서는
이전 지역을 다시 방문하고 지역마다 다른 사건에 대응하며 도감 발견도를
수집할 수 있습니다. V0.3.1에서는 내부 디버그 표시처럼 보인 쥐 장비 도형,
쥐구멍 주변 장식선과 굴 앞 추가 쥐를 제거했습니다.

V0.3.2에서는 `현장 행동`을 추가했습니다. 낡은 부엌에서는 실타래의 연결을
따라 매듭을 풀고, 식료품 창고에서는 선반 철탑을 오르며, 동네 편의점에서는
중앙 신호와 같은 색의 문을 찾아 무한 통로를 빠져나옵니다.

V0.4.0에서는 쥐구멍 Lv.10에 보육실을 건설할 수 있습니다. 작은 새끼 점을
직접 눌러 성장 시간을 단축하고, 성장이 끝난 뒤 `성체 합류`를 선택하면 실제
채집 쥐 수가 증가합니다.

V0.4.1에서는 쥐 3마리부터 `역할` 보드가 열립니다. 역할점을 눌러 채집쥐를
탐험쥐나 건설쥐로 옮기면 채집 생산과 화면 채집조가 줄어드는 대신 지역 보상이나
이후 새끼 성장 속도가 증가합니다.

V0.4.2에서는 쥐 5마리부터 `영웅` 기록이 열립니다. 단단이·새벽·보름의 후보
점을 눌러 이야기와 효과를 확인하고 한 명을 군락의 첫 영웅으로 영구 선택할 수
있습니다.

V0.4.3에서는 선택한 영웅의 고유 점 임무를 직접 수행합니다. 점 5개를 순서대로
완료하면 치즈 보상과 유대 Lv.을 얻고, 유대 Lv.3까지 영웅의 기존 효과가
강해집니다. 임무는 60초 뒤 다시 수행할 수 있으며 진행 상태와 대기 시간은
저장 스키마 8로 관리합니다.

## 실행

Godot 4.x에서 저장소의 `project.godot`를 열고 프로젝트 실행(F5)을 누릅니다.

명령줄에서는 다음과 같이 실행할 수 있습니다.

```bash
godot4 --path . --editor
godot4 --path . --headless --quit-after 3
```

테스트:

```bash
godot4 --path . --headless tests/test_runner.tscn
```

### iPad Web 빌드

Godot 4.7과 Web 내보내기 템플릿을 설치한 뒤 빌드합니다.

```bash
godot4 --path . --headless --export-release Web builds/web/index.html
npm ci
npm run prepare:game
npm run build
```

HTTPS에 배포한 주소를 iPad Safari에서 열 수 있습니다. Safari 공유 메뉴의
**홈 화면에 추가**를 선택하면 앱처럼 실행됩니다. 세이브 데이터는 해당 사이트의
브라우저 저장소에 있으므로 사이트 데이터를 삭제하거나 주소가 바뀌면 이어지지
않을 수 있습니다.

## 문서 안내

처음 참여하거나 전체 방향을 확인할 때는
[`docs/jjugumeong_master_plan.md`](docs/jjugumeong_master_plan.md)를 먼저 읽습니다.

| 문서 | 역할 |
| --- | --- |
| [`docs/jjugumeong_master_plan.md`](docs/jjugumeong_master_plan.md) | 현재 상태, 확정 방향, 다음 작업과 결정 대기 항목 |
| [`docs/game_design.md`](docs/game_design.md) | 핵심 루프, 성장, 보상과 콘텐츠 설계 |
| [`docs/world_lore.md`](docs/world_lore.md) | 세계관, 지역 이야기, 세력과 영웅 |
| [`docs/roadmap.md`](docs/roadmap.md) | 버전별 목표와 완료 조건 |
| [`docs/balancing.md`](docs/balancing.md) | 현재 수치와 다음 밸런스 원칙 |
| [`docs/technical_design.md`](docs/technical_design.md) | 코드 책임, 저장, 데이터와 검증 규칙 |
| [`docs/changelog.md`](docs/changelog.md) | 날짜별 변경 기록 |

문서에서 사용하는 상태는 다음과 같습니다.

- **구현됨**: 현재 코드와 데이터로 실행되는 기능
- **다음**: 다음 버전에서 구현하기로 확정한 기능
- **장기**: 방향은 합의했지만 일정이 확정되지 않은 기능
- **결정 대기**: 구현 전에 플레이 테스트나 선택이 필요한 기능

## 프로젝트 구조

| 경로 | 책임 |
| --- | --- |
| `scenes/` | 메인, 월드, 쥐와 UI 씬 |
| `scripts/core/` | 게임 상태, 이벤트와 저장 |
| `scripts/mouse/` | 쥐 이동과 표현 |
| `scripts/world/` | 배경, 경로와 지역 표현 |
| `scripts/ui/` | UI 생성과 반응형 배치 |
| `data/` | 스테이지, 쥐, 자원, 사건과 확장 데이터 |
| `tests/` | headless 회귀 테스트 |
| `docs/` | 기획, 세계관, 기술, 밸런스와 변경 기록 |
| `app/`, `tools/` | iPad Web/PWA 호스팅 래퍼와 빌드 준비 |

저장 파일은 `user://savegame.json`, 백업은
`user://savegame.backup.json`에 생성됩니다.
