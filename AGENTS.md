# CanYouKickNow — AGENTS.md
> **AI 에이전트 및 다중 환경 개발자용 공유 노트**
> 세션 시작 전 반드시 `git pull` 후 이 파일을 읽을 것.
> 세션 종료 전 반드시 이 파일을 업데이트하고 커밋할 것.

---

## 현재 상태

| 항목 | 내용 |
|---|---|
| **버전** | v1.0.0 (개발 중, 미배포) |
| **마지막 작업** | 2026-04-01 (초기 개발 완료, Claude Code) |
| **안정성** | 인게임 테스트 미완료 |
| **GitHub** | https://github.com/kimgod1142/CanYouKickNow |
| **CurseForge** | 미등록 |

---

## 마지막 세션에서 한 것 (Session 1 — 2026-04-01)

- 초기 개발 완료:
  - SpellDB: 13개 클래스 차단기 데이터 (CKYN_SPELLS, CKYN_SPEC_INTERRUPT, CKYN_CD_REDUCE)
  - Inspect 큐: GetInspectSpecialization 기반 스펙 확인 (4초 타임아웃)
  - M+ 자동 감지: C_ChallengeMode.GetActiveChallengeMapID()
  - UI: 5가지 상태 (추적불가/차단없음/미확인/쿨다운/준비)
  - Options.lua: 슬라이더, 텍스처 드롭다운, 체크박스
  - /ckn test, /ckn config 슬래시 명령어
  - README.md, curseforge-description.html (미커밋 상태)
- Loxx Interrupt Tracker 역공학 분석 완료 (RESEARCH_NOTES.md 참고)

---

## 다음 우선순위

> **⚠️ 현재 RMT 완성이 우선. CKYN은 보류 상태.**

1. README.md, curseforge-description.html 커밋 (untracked 상태)
2. 인게임 M+ 실전 테스트 (가장 중요)
3. Loxx 분석 결과 반영 (우선순위 낮음, RMT 완성 후):
   - Warlock spell alias (19647/132409/119914/89766/1276467)
   - `~` 추정 뱃지 표시
   - pcall 방어 코딩
   - GCD 오염값 필터

---

## 알려진 이슈

| 이슈 | 심각도 | 상태 |
|---|---|---|
| Warlock 차단기 추적 불가 (페트 스펠) | 중 | 설계상 한계, "— 추적 불가" 표시 |
| Inspect 30야드 거리 제한 | 낮음 | 근처에 없으면 스펙 미확인 상태 유지 |
| 파티원 CD가 전부 추정 (통신 없음) | 중 | v1.2 계획에 통신 프로토콜 추가 예정 |
| README.md, curseforge-description.html 미커밋 | 낮음 | untracked 상태 |

---

## 핵심 설계 결정

### 애드온 없어도 추적 가능한 이유
`UnitClass("party1")` 은 서버 데이터 — 상대방 애드온 불필요.
`UNIT_SPELLCAST_SUCCEEDED` + `RegisterUnitEvent("party1"..4)` 로 모든 파티원 시전 감지.

### Warlock 한계
페트 스킬(Spell Lock, Axe Toss)은 player unitID에서 UNIT_SPELLCAST_SUCCEEDED 미발생.
현재: "— 추적 불가" 표시. Loxx의 spell alias 방식으로 개선 가능하나 RMT 이후 작업.

### Inspect 큐
`NotifyInspect(unit)` → INSPECT_READY → `GetInspectSpecialization()`.
스팸 방지: 한 번에 1명, 4초 타임아웃 후 다음 처리.

---

## 파일 구조

```
CanYouKickNow/
├── AGENTS.md               ← 이 파일 (공유 노트)
├── CanYouKickNow.toc
├── CanYouKickNow.lua       ← 코어 (로스터, Inspect 큐, 이벤트)
├── SpellDB.lua             ← 차단기 DB
├── UI.lua                  ← 패널
├── Options.lua             ← 설정창
├── README.md               ← (untracked — 커밋 필요)
└── curseforge-description.html  ← (untracked — 커밋 필요)
```

---

## 워크플로우

```bash
# 세션 시작
git pull
# → AGENTS.md 읽기 (지금 이 파일)

# 작업 후
# → AGENTS.md "마지막 세션에서 한 것" 업데이트
# → "다음 우선순위" 업데이트
git add -A
git commit -m "..."
git push
```
