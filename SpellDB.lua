-- SpellDB.lua
-- 직업별 차단 스킬 정의
--
-- ── 필드 설명 ────────────────────────────────────────────────────────────
--   talent = true  : 특성을 찍어야 사용 가능 (기본 스킬 아님)
--                    → 본인은 IsPlayerSpell()로 확인
--                    → 파티원은 실제 사용 전까지 보유 여부 불명확
--   talent = false : 기본 스킬 (해당 직업/스펙이면 무조건 보유)
--
-- ── 검증 상태 ────────────────────────────────────────────────────────────
--   ✅ 인게임 확인 완료
--   ❓ 미확인 — /script print(GetSpellInfo(ID)) 로 확인 필요
--
-- ── CKYN_CLASS_DEFAULT ───────────────────────────────────────────────────
--   클래스별 가능한 차단 스킬 목록 (여러 개 = 스펙 의존)
--   본인: IsPlayerSpell()로 확정
--   타인: 실제 사용 전까지 "?" 상태로 표시 (talent=true 직업)
--         talent=false면 무조건 보유로 간주해 미리 표시

CKYN_SPELLS = {

    -- ── 전사 ─────────────────────────────────────────── ✅ 기본 스킬
    [6552] = {
        class    = "WARRIOR",
        name     = "Pummel",
        name_ko  = "강타",
        cd       = 15,
        talent   = false,
        icon     = 132938,
    },

    -- ── 성기사 ───────────────────────────────────────── ✅ 특성 (보호/징벌만)
    -- 신성 성기사는 이 특성 트리에 없음
    [96231] = {
        class    = "PALADIN",
        name     = "Rebuke",
        name_ko  = "비난",
        cd       = 15,
        talent   = true,
        icon     = 523893,
    },

    -- ── 헌터 ─────────────────────────────────────────── ❓ 기본/특성 여부 미확인
    -- 사격: Counter Shot (원거리 전용)
    -- 야수/생존: Muzzle (근접 전용)
    [147362] = {
        class    = "HUNTER",
        name     = "Counter Shot",
        name_ko  = "반격 사격",
        cd       = 24,
        talent   = false,  -- ❓ 기본 스킬 여부 확인 필요
        icon     = 1376044,
    },
    [187707] = {
        class    = "HUNTER",
        name     = "Muzzle",
        name_ko  = "재갈",
        cd       = 15,
        talent   = false,  -- ❓ 기본 스킬 여부 확인 필요
        icon     = 1376045,
    },

    -- ── 도적 ─────────────────────────────────────────── ❓ 기본/특성 여부 미확인
    [1766] = {
        class    = "ROGUE",
        name     = "Kick",
        name_ko  = "발차기",
        cd       = 15,
        talent   = false,  -- ❓ 확인 필요
        icon     = 132219,
    },

    -- ── 죽음의 기사 ──────────────────────────────────── ❓ 기본/특성 여부 미확인
    [47528] = {
        class    = "DEATHKNIGHT",
        name     = "Mind Freeze",
        name_ko  = "정신 결빙",
        cd       = 15,
        talent   = false,  -- ❓ 확인 필요
        icon     = 237527,
    },

    -- ── 주술사 ───────────────────────────────────────── ✅ 특성 (전 스펙 공통 트리)
    [57994] = {
        class    = "SHAMAN",
        name     = "Wind Shear",
        name_ko  = "날카로운 바람",
        cd       = 12,
        talent   = true,
        icon     = 136018,
    },

    -- ── 마법사 ───────────────────────────────────────── ❓ 기본/특성 여부 미확인
    [2139] = {
        class    = "MAGE",
        name     = "Counterspell",
        name_ko  = "마법 차단",
        cd       = 24,
        talent   = false,  -- ❓ 확인 필요
        icon     = 135856,
    },

    -- ── 흑마법사 ─────────────────────────────────────── ❓ 펫 스킬 감지 여부 미확인
    -- 지옥사냥개/감시자: Spell Lock (24s)
    -- 악마군주/분노군주: Axe Toss (30s)
    -- 흑마 본인이 UNIT_SPELLCAST_SUCCEEDED에 잡히는지 인게임 확인 필요
    [19647] = {
        class    = "WARLOCK",
        name     = "Spell Lock",
        name_ko  = "주문 봉쇄",
        cd       = 24,
        talent   = false,  -- ❓ 펫 시전 스킬 — 감지 가능 여부 확인 필요
        icon     = 136174,
    },

    -- ── 수도사 ───────────────────────────────────────── ❓ 기본/특성 여부 미확인
    [116705] = {
        class    = "MONK",
        name     = "Spear Hand Strike",
        name_ko  = "창손 치기",
        cd       = 15,
        talent   = false,  -- ❓ 확인 필요
        icon     = 608951,
    },

    -- ── 드루이드 ─────────────────────────────────────── ✅ 스펙별 상이
    -- 야성/수호/신성: 해골 강타 (Skull Bash, 15s)
    -- 조화: 태양 광선 (Solar Beam, 60s) — 완전히 다른 스킬
    [106839] = {
        class    = "DRUID",
        name     = "Skull Bash",
        name_ko  = "해골 강타",
        cd       = 15,
        talent   = false,  -- ❓ 기본 스킬 여부 확인 필요
        icon     = 236946,
    },
    [78675] = {           -- ✅ 조화 드루이드 전용
        class    = "DRUID",
        name     = "Solar Beam",
        name_ko  = "태양 광선",
        cd       = 60,
        talent   = true,   -- ✅ 조화 특성 필요
        icon     = 135753,
    },

    -- ── 악마사냥꾼 ───────────────────────────────────── ❓ 기본/특성 여부 미확인
    [183752] = {
        class    = "DEMONHUNTER",
        name     = "Disrupt",
        name_ko  = "방해",
        cd       = 15,
        talent   = false,  -- ❓ 확인 필요
        icon     = 1305156,
    },

    -- ── 기원사 ───────────────────────────────────────── ❓ 기본/특성 여부 미확인
    [351189] = {
        class    = "EVOKER",
        name     = "Quell",
        name_ko  = "억제",
        cd       = 30,
        talent   = false,  -- ❓ 확인 필요
        icon     = 4622300,
    },

    -- ── 사제 ─────────────────────────────────────────── ❓ 전체 미확인
    -- 암흑: Silence (15208, 45s) — 특성 필요 가능성 높음
    -- [15208] = {
    --     class   = "PRIEST",
    --     name    = "Silence",
    --     name_ko = "침묵",
    --     cd      = 45,
    --     talent  = true,
    --     icon    = 136091,
    -- },
}

-- ── 클래스별 가능한 차단 스킬 목록 ─────────────────────────────────────
-- talent=false 직업: 무조건 보유 → 파티원도 사전 표시
-- talent=true  직업: 특성 의존 → 본인만 IsPlayerSpell()로 확인,
--                               파티원은 실제 사용 전까지 "?" 표시
CKYN_CLASS_DEFAULT = {
    WARRIOR     = { 6552             },  -- talent=false, 사전 표시
    PALADIN     = { 96231            },  -- talent=true,  "?" 표시
    HUNTER      = { 147362, 187707   },  -- 스펙 의존 (Counter Shot or Muzzle)
    ROGUE       = { 1766             },
    DEATHKNIGHT = { 47528            },
    SHAMAN      = { 57994            },  -- talent=true,  "?" 표시
    MAGE        = { 2139             },
    WARLOCK     = { 19647            },  -- ❓ 펫 스킬 감지 확인 후 유지/제거
    MONK        = { 116705           },
    DRUID       = { 106839, 78675    },  -- Skull Bash(야성/수호/신성) or Solar Beam(조화)
    DEMONHUNTER = { 183752           },
    EVOKER      = { 351189           },
    PRIEST      = {},                    -- 차단 없음 (침묵은 별도 확인 필요)
}
