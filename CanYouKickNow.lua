-- CanYouKickNow.lua
-- M+ 파티 차단기 쿨타임 추적 애드온
--
-- 특징:
--   - 파티원 전원에게 패널 표시 (공대장 제한 없음)
--   - UnitClass()로 클래스 감지, UNIT_SPELLCAST_SUCCEEDED로 사용 감지
--   - 상대방 애드온 없어도 동작
--
-- ── 로스터 구성 방식 ────────────────────────────────────────────────────
--   talent=false 스킬: 해당 클래스면 무조건 보유 → 파티원도 사전 표시
--   talent=true  스킬: 특성 의존 → 본인은 IsPlayerSpell()로 확인
--                                   파티원은 "?" 상태로 표시, 실제 사용 시 확정
--
-- Author:  kimgod1142
-- License: MIT

local ADDON_NAME = "CanYouKickNow"
local VERSION    = "1.0.0"

-- ⚠️ CKYN global — UI.lua에서도 참조
CKYN = {
    -- [unitID] = {
    --   name, class, spellID, cd, endTime,
    --   confirmed  -- false: 실제 차단 사용 전 (talent 직업 타인), true: 확정
    -- }
    roster = {},
}

-- ================================================================
-- HELPERS
-- ================================================================
local function Log(msg)
    print("|cff00ff99[CKYN]|r " .. tostring(msg))
end

local function GetShortName(unitID)
    local name = UnitName(unitID)
    if not name then return nil end
    return name:match("^([^%-]+)") or name
end

-- 클래스의 기본 차단 스킬 결정
-- talent=false 스킬 우선, 없으면 첫 번째 항목
-- 반환: spellID or nil, confirmed(bool)
local function ResolveSpellForUnit(unitID, classFile)
    local defaults = CKYN_CLASS_DEFAULT[classFile]
    if not defaults or #defaults == 0 then return nil, false end

    -- 본인: IsPlayerSpell()로 실제 보유 확인
    if unitID == "player" then
        for _, sid in ipairs(defaults) do
            if IsPlayerSpell(sid) then
                return sid, true
            end
        end
        return nil, false  -- 특성 미보유
    end

    -- 타인: talent=false 스킬은 무조건 보유로 간주
    --       talent=true  스킬만 있는 직업은 "?" 상태
    for _, sid in ipairs(defaults) do
        local data = CKYN_SPELLS[sid]
        if data and data.talent == false then
            return sid, true  -- 확정 (기본 스킬)
        end
    end

    -- talent=true 스킬만 있는 직업 → 첫 번째를 "미확인" 상태로
    return defaults[1], false
end

-- ================================================================
-- ROSTER
-- ================================================================
local function BuildRoster()
    -- 재구성 시 기존 쿨타임 및 confirmed 상태 보존
    local prev = {}
    for unitID, entry in pairs(CKYN.roster) do
        prev[unitID] = {
            spellID   = entry.spellID,
            endTime   = entry.endTime,
            confirmed = entry.confirmed,
        }
    end

    CKYN.roster = {}

    local units = { "player", "party1", "party2", "party3", "party4" }
    for _, unitID in ipairs(units) do
        if not UnitExists(unitID) then break end

        local name = GetShortName(unitID)
        local _, classFile = UnitClass(unitID)
        if not name or not classFile then goto continue end

        local spellID, confirmed = ResolveSpellForUnit(unitID, classFile)

        -- 차단 스킬 없는 직업(사제 등)도 "차단 없음" 상태로 패널에 표시
        -- spellID = nil 이면 UI에서 "없음" 처리

        -- 이전 상태 복원
        local p       = prev[unitID]
        local endTime = 0
        if p and p.spellID == spellID then
            endTime   = p.endTime
            confirmed = confirmed or p.confirmed  -- 이전에 confirmed였으면 유지
        end

        local cd = 15
        if spellID then
            local data = CKYN_SPELLS[spellID]
            cd = data and data.cd or 15
        end

        CKYN.roster[unitID] = {
            name      = name,
            class     = classFile,
            spellID   = spellID,   -- nil = 차단 스킬 없음
            cd        = cd,
            endTime   = endTime,
            confirmed = confirmed, -- false = 특성 미확인 (타인 talent 직업)
        }

        ::continue::
    end

    CKYN_UI_Refresh()
end

-- ================================================================
-- CAST DETECTION
-- ================================================================
local function OnUnitSpellCast(unitID, spellID)
    local data = CKYN_SPELLS[spellID]
    if not data then return end

    local now  = GetTime()
    local name = GetShortName(unitID)
    local _, classFile = UnitClass(unitID)
    if not name then return end

    if CKYN.roster[unitID] then
        local entry     = CKYN.roster[unitID]
        -- 스펙 교정 (예: 헌터가 Muzzle 쓰면 Counter Shot → Muzzle)
        entry.spellID   = spellID
        entry.cd        = data.cd
        entry.endTime   = now + data.cd
        entry.confirmed = true   -- 실제 사용 확인 → confirmed
    else
        -- 로스터에 없던 유닛 (드물지만 안전하게 처리)
        CKYN.roster[unitID] = {
            name      = name,
            class     = classFile or data.class or "",
            spellID   = spellID,
            cd        = data.cd,
            endTime   = now + data.cd,
            confirmed = true,
        }
    end

    CKYN_UI_Refresh()
end

-- ================================================================
-- COMMANDS
-- /ckn          → 패널 토글
-- /ckn reset    → 쿨타임 초기화
-- /ckn reload   → 로스터 재스캔
-- ================================================================
SLASH_CKYN1 = "/ckn"
SlashCmdList["CKYN"] = function(msg)
    local arg = msg and msg:lower():match("^%s*(%S*)") or ""
    if arg == "reset" then
        for _, entry in pairs(CKYN.roster) do
            entry.endTime = 0
        end
        CKYN_UI_Refresh()
        Log("쿨타임 초기화")
    elseif arg == "reload" then
        BuildRoster()
        Log("로스터 재스캔 완료")
    else
        CKYN_UI_Toggle()
    end
end

-- ================================================================
-- INIT
-- ================================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("GROUP_ROSTER_UPDATE")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        CKYNdb = CKYNdb or {}
        CKYN_UI_Init()
        Log("v" .. VERSION .. "  |cff888888/ckn|r")

    elseif event == "GROUP_ROSTER_UPDATE" then
        C_Timer.After(0.5, BuildRoster)

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, BuildRoster)
    end
end)

-- 스킬 사용 감지 (taint 방지: loader와 분리된 프레임)
local castFrame = CreateFrame("Frame")
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED",
    "player", "party1", "party2", "party3", "party4")
castFrame:SetScript("OnEvent", function(_, _, unitID, _, spellID)
    OnUnitSpellCast(unitID, spellID)
end)
