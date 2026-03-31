-- CanYouKickNow.lua
-- M+ 파티 차단기 쿨타임 추적 애드온
--
-- 특징:
--   - 파티원 전원에게 패널 표시 (공대장 제한 없음)
--   - 애드온 메시지 불필요: UnitClass()로 클래스 감지, UNIT_SPELLCAST_SUCCEEDED로 사용 감지
--   - 상대방 애드온 없어도 동작
--
-- Author:  kimgod1142
-- Contact: kimgod1142@gmail.com
-- License: MIT

local ADDON_NAME = "CanYouKickNow"
local VERSION    = "1.0.0"

-- ⚠️ CKYN은 global — UI.lua에서도 참조
CKYN = {
    -- [unitID] = { name, class, spellID, cd, endTime }
    roster = {},
}

-- ================================================================
-- HELPERS
-- ================================================================
local function Log(msg)
    print("|cff00ff99[CKYN]|r " .. tostring(msg))
end

-- unitID에서 서버명 없는 이름 반환
local function GetShortName(unitID)
    local name = UnitName(unitID)
    if not name then return nil end
    return name:match("^([^%-]+)") or name
end

-- ================================================================
-- ROSTER
-- 파티 구성 변경 시 UnitClass()로 클래스 읽어 로스터 재구성
-- 스펙 의존 직업(헌터 등)은 기본값으로 선점, 실제 사용 시 자동 교정
-- ================================================================
local function BuildRoster()
    -- 기존 endTime 보존: 재구성해도 쿨타임 데이터는 유지
    local prevEndTimes = {}
    for unitID, entry in pairs(CKYN.roster) do
        prevEndTimes[unitID] = { spellID = entry.spellID, endTime = entry.endTime }
    end

    CKYN.roster = {}

    local units = { "player", "party1", "party2", "party3", "party4" }
    for _, unitID in ipairs(units) do
        if not UnitExists(unitID) then break end

        local name = GetShortName(unitID)
        local _, classFile = UnitClass(unitID)
        if not name or not classFile then goto continue end

        local defaults = CKYN_CLASS_DEFAULT[classFile]
        if not defaults or #defaults == 0 then goto continue end

        -- 본인: IsPlayerSpell로 현재 스펙 스킬 확정
        -- 타인: 기본값(defaults[1])으로 선점, 실제 사용 시 교정
        local spellID
        if unitID == "player" then
            for _, sid in ipairs(defaults) do
                if IsPlayerSpell(sid) then
                    spellID = sid
                    break
                end
            end
        else
            spellID = defaults[1]
        end

        if not spellID then goto continue end

        local data = CKYN_SPELLS[spellID]

        -- 이전 쿨타임 복원 (같은 유닛, 같은 스킬이면)
        local prev    = prevEndTimes[unitID]
        local endTime = (prev and prev.spellID == spellID) and prev.endTime or 0

        CKYN.roster[unitID] = {
            name    = name,
            class   = classFile,
            spellID = spellID,
            cd      = data and data.cd or 15,
            endTime = endTime,
        }

        ::continue::
    end

    CKYN_UI_Refresh()
end

-- ================================================================
-- CAST DETECTION
-- UNIT_SPELLCAST_SUCCEEDED: 파티원이 추적 스킬 사용 시 쿨타임 기록
-- ================================================================
local function OnUnitSpellCast(unitID, spellID)
    local data = CKYN_SPELLS[spellID]
    if not data then return end

    local now  = GetTime()
    local name = GetShortName(unitID)
    local _, classFile = UnitClass(unitID)

    if not name then return end

    -- 로스터에 없는 유닛이면 등록 (애드온 없는 파티원도 감지 가능)
    if not CKYN.roster[unitID] then
        CKYN.roster[unitID] = {
            name    = name,
            class   = classFile or data.class or "",
            spellID = spellID,
            cd      = data.cd,
            endTime = now + data.cd,
        }
    else
        local entry = CKYN.roster[unitID]
        -- 스펙 오판이었을 경우 교정 (예: 헌터가 Muzzle 쓰면 Counter Shot → Muzzle 로 교정)
        entry.spellID = spellID
        entry.cd      = data.cd
        entry.endTime = now + data.cd
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
        Log("쿨타임 초기화 완료")
    elseif arg == "reload" then
        BuildRoster()
        Log("로스터 재스캔 완료")
    else
        -- 기본: 패널 토글
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
        -- 파티 구성 변경: 약간 지연 후 재스캔 (WoW가 UnitClass 반환하기까지 1프레임 필요)
        C_Timer.After(0.5, BuildRoster)

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 로딩 화면 후 로스터 재구성
        C_Timer.After(1, BuildRoster)
    end
end)

-- 스킬 사용 감지 프레임 (ADDON_LOADED와 분리: taint 방지)
local castFrame = CreateFrame("Frame")
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED",
    "player", "party1", "party2", "party3", "party4")
castFrame:SetScript("OnEvent", function(_, _, unitID, _, spellID)
    OnUnitSpellCast(unitID, spellID)
end)
