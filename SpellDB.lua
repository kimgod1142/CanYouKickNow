-- SpellDB.lua
-- 직업별 차단 스킬 정의
--
-- ⚠️ 검증 필요 항목은 -- ❓ 주석으로 표시
-- 인게임에서 /script print(GetSpellInfo(스펠ID)) 로 확인 후 수정 바람
--
-- 구조:
--   CKYN_SPELLS[spellID] = { class, name, name_ko, cd, icon }
--     → 스킬 사용 감지 및 쿨타임 계산에 사용
--
--   CKYN_CLASS_DEFAULT[classFile] = { spellID, ... }
--     → 파티 합류 시 클래스 기반 로스터 선점성 구성
--     → 스펙 의존 직업(헌터 등)은 여러 개 나열, 실제 사용 시 자동 교정됨

CKYN_SPELLS = {

    -- ── 전사 ──────────────────────────────────────────────────────
    [6552] = {
        class    = "WARRIOR",
        name     = "Pummel",
        name_ko  = "강타",
        cd       = 15,
        icon     = 132938,
    },

    -- ── 성기사 ────────────────────────────────────────────────────
    [96231] = {
        class    = "PALADIN",
        name     = "Rebuke",
        name_ko  = "꾸짖기",
        cd       = 15,
        icon     = 523893,
    },

    -- ── 헌터 ──────────────────────────────────────────────────────
    -- 사격: Counter Shot (원거리 전용, 24s)
    -- 야수/생존: Muzzle (근접 전용, 15s)
    -- → 로스터 선점 시 Counter Shot 기본, 실제 사용 스킬로 자동 교정
    [147362] = {  -- ❓ spellID 재확인 권장
        class    = "HUNTER",
        name     = "Counter Shot",
        name_ko  = "반격 사격",
        cd       = 24,
        icon     = 1376044,
    },
    [187707] = {  -- ❓ spellID 재확인 권장
        class    = "HUNTER",
        name     = "Muzzle",
        name_ko  = "재갈",
        cd       = 15,
        icon     = 1376045,
    },

    -- ── 도적 ──────────────────────────────────────────────────────
    [1766] = {
        class    = "ROGUE",
        name     = "Kick",
        name_ko  = "발차기",
        cd       = 15,
        icon     = 132219,
    },

    -- ── 죽음의 기사 ───────────────────────────────────────────────
    [47528] = {
        class    = "DEATHKNIGHT",
        name     = "Mind Freeze",
        name_ko  = "정신 결빙",
        cd       = 15,
        icon     = 237527,
    },

    -- ── 주술사 ────────────────────────────────────────────────────
    [57994] = {
        class    = "SHAMAN",
        name     = "Wind Shear",
        name_ko  = "바람 가르기",
        cd       = 12,
        icon     = 136018,
    },

    -- ── 마법사 ────────────────────────────────────────────────────
    [2139] = {
        class    = "MAGE",
        name     = "Counterspell",
        name_ko  = "마법 차단",
        cd       = 24,
        icon     = 135856,
    },

    -- ── 흑마법사 ──────────────────────────────────────────────────
    -- 펫 스킬 (지옥사냥개/감시자: Spell Lock, 악마군주/분노군주: Axe Toss)
    -- 흑마 본인이 UNIT_SPELLCAST_SUCCEEDED에 잡히는지 인게임 확인 필요
    [19647] = {  -- ❓ Spell Lock — 펫 시전 여부 확인 필요
        class    = "WARLOCK",
        name     = "Spell Lock",
        name_ko  = "주문 봉쇄",
        cd       = 24,
        icon     = 136174,
    },

    -- ── 수도사 ────────────────────────────────────────────────────
    [116705] = {
        class    = "MONK",
        name     = "Spear Hand Strike",
        name_ko  = "창손 치기",
        cd       = 15,
        icon     = 608951,
    },

    -- ── 드루이드 ──────────────────────────────────────────────────
    [106839] = {
        class    = "DRUID",
        name     = "Skull Bash",
        name_ko  = "해골 강타",
        cd       = 15,
        icon     = 236946,
    },

    -- ── 악마사냥꾼 ────────────────────────────────────────────────
    [183752] = {
        class    = "DEMONHUNTER",
        name     = "Disrupt",
        name_ko  = "방해",
        cd       = 15,
        icon     = 1305156,
    },

    -- ── 기원사 ────────────────────────────────────────────────────
    [351189] = {  -- ❓ spellID 재확인 권장
        class    = "EVOKER",
        name     = "Quell",
        name_ko  = "억제",
        cd       = 30,
        icon     = 4622300,
    },

    -- ── 사제 ──────────────────────────────────────────────────────
    -- 기본 차단기 없음. 암흑 사제: Silence (15208, 45s) — 특성 필요
    -- ❓ 현재 패치에서 사제 차단 수단 재확인 필요
    -- [15208] = {
    --     class   = "PRIEST",
    --     name    = "Silence",
    --     name_ko = "침묵",
    --     cd      = 45,
    --     icon    = 136091,
    -- },
}

-- 클래스별 기본 차단 스킬 (로스터 선점용)
-- 스펙 의존 직업은 첫 번째가 기본값, 실제 사용 스킬로 자동 교정됨
CKYN_CLASS_DEFAULT = {
    WARRIOR     = { 6552   },
    PALADIN     = { 96231  },
    HUNTER      = { 147362, 187707 },  -- Counter Shot 기본, Muzzle 교정용
    ROGUE       = { 1766   },
    DEATHKNIGHT = { 47528  },
    SHAMAN      = { 57994  },
    MAGE        = { 2139   },
    WARLOCK     = { 19647  },          -- ❓ 펫 감지 여부 확인 후 제거 가능
    MONK        = { 116705 },
    DRUID       = { 106839 },
    DEMONHUNTER = { 183752 },
    EVOKER      = { 351189 },
    PRIEST      = {},                  -- 기본 차단 없음
}
