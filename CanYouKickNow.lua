-- CanYouKickNow.lua
-- M+ 파티 차단기 쿨타임 추적 애드온
--
-- ── 동작 흐름 ────────────────────────────────────────────────────────────
--   1. M+ 던전 진입 감지 → 패널 자동 표시 + Inspect 큐 실행
--   2. Inspect: GetInspectSpecialization → 스펙 확인 → 차단 스킬 확정
--      - talent=true 스킬: Inspect 성공 시 confirmed, 실패 시 "?" 유지
--      - talent=false 스킬: Inspect 없이도 confirmed
--      - 사거리 밖 등 Inspect 불가: "?" 상태 유지 → 실제 사용 시 자동 교정
--   3. UNIT_SPELLCAST_SUCCEEDED: 실제 차단 사용 감지 → 쿨타임 기록 + 스펙 교정
--   4. M+ 던전 이탈 → 패널 자동 숨김 + 로스터 초기화
--
-- Author:  kimgod1142
-- License: MIT

local ADDON_NAME = "CanYouKickNow"
local VERSION    = "1.0.0"

-- ⚠️ CKYN global — UI.lua에서도 참조
CKYN = {
    -- [unitID] = {
    --   name      : 플레이어 이름 (서버명 제외)
    --   class     : 직업 파일명 ("WARRIOR" 등)
    --   spellID   : 차단 스킬 ID (nil = 차단 없음 확정 or API 한계)
    --   cd        : 쿨타임 (초). Inspect 쿨 감소 특성 확인 시 조정됨
    --   endTime   : castTime + cd (0 = 아직 사용 안 함 = READY)
    --   confirmed : true  = 보유 확정 (기본 스킬 or Inspect or 실제 사용)
    --               false = 특성 미확인 ("?" 표시)
    --   noKick    : true  = 차단 없음 확정 (신성 성기사, 보존 기원사 등)
    --   apiLimit  : true  = 흑마법사 등 API 한계로 추적 불가
    --   specID    : Inspect 후 확정된 specID
    -- }
    roster       = {},
    inMythicPlus = false,
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

-- M+ 던전 안에 있는지 판별
local function IsInMythicPlus()
    local _, instanceType = IsInInstance()
    if instanceType ~= "party" then return false end
    -- GetActiveChallengeMapID: 쐐기 모드 던전이면 양수 반환 (키 활성 전후 모두)
    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and
                  C_ChallengeMode.GetActiveChallengeMapID()
    return mapID ~= nil and mapID > 0
end

-- ================================================================
-- INSPECT 큐
-- NotifyInspect는 연속 호출 불가 → 큐로 순차 처리
-- ================================================================
local inspectQueue   = {}
local inspectPending = false
local INSPECT_TIMEOUT = 4   -- 초: 이 시간 안에 INSPECT_READY 없으면 다음으로

local function ProcessInspectQueue()
    if inspectPending or #inspectQueue == 0 then return end

    local unitID = table.remove(inspectQueue, 1)

    -- 유닛 존재 + 30야드 이내 (CheckInteractDistance 1 = 검사 가능 거리)
    if not UnitExists(unitID) or not CheckInteractDistance(unitID, 1) then
        ProcessInspectQueue()  -- 건너뛰고 다음
        return
    end

    NotifyInspect(unitID)
    inspectPending = true

    -- 타임아웃: INSPECT_READY가 안 오면 다음 유닛으로
    C_Timer.After(INSPECT_TIMEOUT, function()
        if inspectPending then
            inspectPending = false
            ClearInspectPlayer()
            ProcessInspectQueue()
        end
    end)
end

local function QueueInspect(unitID)
    if unitID == "player" then return end  -- 본인은 IsPlayerSpell()로 처리
    -- 중복 방지
    for _, u in ipairs(inspectQueue) do
        if u == unitID then return end
    end
    inspectQueue[#inspectQueue + 1] = unitID
    C_Timer.After(0.3, ProcessInspectQueue)  -- 약간 지연 후 시작
end

local function InspectAllParty()
    inspectQueue = {}
    inspectPending = false
    for i = 1, 4 do
        local unitID = "party" .. i
        if UnitExists(unitID) then
            QueueInspect(unitID)
        end
    end
end

-- ================================================================
-- ROSTER
-- ================================================================

-- 본인 차단 스킬: IsPlayerSpell()로 실제 보유 확인
local function ResolvePlayerSpell()
    local defaults = CKYN_CLASS_DEFAULT
    local _, classFile = UnitClass("player")
    if not classFile then return nil, false end
    local spells = defaults[classFile]
    if not spells then return nil, false end
    for _, sid in ipairs(spells) do
        if IsPlayerSpell(sid) then return sid, true end
    end
    return nil, false
end

-- 타인: 클래스 기반 기본값 (Inspect 전 상태)
-- talent=false → confirmed=true (기본 스킬, 무조건 보유)
-- talent=true  → confirmed=false ("?" 표시)
-- WARLOCK      → apiLimit=true
local function ResolveClassDefault(classFile)
    -- 흑마법사: API 한계
    if classFile == "WARLOCK" then
        return nil, false, true  -- spellID, confirmed, apiLimit
    end

    local spells = CKYN_CLASS_DEFAULT[classFile]
    if not spells or #spells == 0 then
        return nil, true, false  -- 차단 없음 확정 (사제 etc는 Inspect 후 분기)
    end

    local sid  = spells[1]
    local data = CKYN_SPELLS[sid]
    local confirmed = data and (data.talent == false)
    return sid, confirmed, false
end

local function BuildRoster()
    -- 재구성 시 기존 쿨타임 보존
    local prev = {}
    for unitID, entry in pairs(CKYN.roster) do
        prev[unitID] = { spellID = entry.spellID, endTime = entry.endTime,
                         confirmed = entry.confirmed, specID = entry.specID }
    end

    CKYN.roster = {}
    local units = { "player", "party1", "party2", "party3", "party4" }

    for _, unitID in ipairs(units) do
        if not UnitExists(unitID) then goto continue end

        local name = GetShortName(unitID)
        local _, classFile = UnitClass(unitID)
        if not name or not classFile then goto continue end

        local spellID, confirmed, apiLimit, noKick

        if unitID == "player" then
            spellID, confirmed = ResolvePlayerSpell()
            apiLimit = false
            noKick   = (spellID == nil)
        else
            -- 이전에 Inspect로 specID 확정됐으면 재사용
            local p = prev[unitID]
            if p and p.specID then
                -- CKYN_SPEC_INTERRUPT에 등록된 스펙: 결과 확정
                spellID   = CKYN_SPEC_INTERRUPT[p.specID]
                confirmed = true   -- specID 자체가 확정됐으면 차단 없음도 confirmed
                noKick    = (spellID == nil)
                apiLimit  = false
            else
                spellID, confirmed, apiLimit = ResolveClassDefault(classFile)
                noKick = (not apiLimit and spellID == nil and confirmed)
            end
        end

        local p       = prev[unitID]
        local endTime = (p and p.spellID == spellID) and p.endTime or 0
        local specID  = (p and p.specID) or nil

        local cd = 15
        if spellID then
            local data = CKYN_SPELLS[spellID]
            cd = data and data.cd or 15
        end

        CKYN.roster[unitID] = {
            name      = name,
            class     = classFile,
            spellID   = spellID,
            cd        = cd,
            endTime   = endTime,
            confirmed = confirmed,
            noKick    = noKick,
            apiLimit  = apiLimit,
            specID    = specID,
        }

        ::continue::
    end

    CKYN_UI_Refresh()
end

-- ================================================================
-- INSPECT 결과 처리
-- INSPECT_READY 이벤트에서 호출
-- ================================================================
local function OnInspectReady(guid)
    -- GUID로 어떤 파티원인지 찾기
    local units = { "party1", "party2", "party3", "party4" }
    local targetUnit

    for _, unitID in ipairs(units) do
        if UnitGUID(unitID) == guid then
            targetUnit = unitID
            break
        end
    end

    if not targetUnit then
        inspectPending = false
        ClearInspectPlayer()
        ProcessInspectQueue()
        return
    end

    local specID  = GetInspectSpecialization(targetUnit)
    local entry   = CKYN.roster[targetUnit]

    if entry and specID and specID > 0 then
        entry.specID = specID

        local newSpell    = CKYN_SPEC_INTERRUPT[specID]
        entry.spellID     = newSpell
        entry.confirmed   = true
        entry.noKick      = (newSpell == nil)
        entry.apiLimit    = false

        if newSpell then
            local data = CKYN_SPELLS[newSpell]
            entry.cd   = data and data.cd or entry.cd

            -- 쿨 감소 특성 확인 (CKYN_CD_REDUCE)
            -- Inspect 대상 유닛의 특성을 IsPlayerSpell로는 확인 불가
            -- → GetInspectSpecialization만으론 개별 특성 노드 확인 어려움
            -- → 현재 구현 방식: 본인(player)만 로그인 시 적용, 타인은 기본 cd 사용
            if targetUnit == "player" then
                for _, r in ipairs(CKYN_CD_REDUCE) do
                    if r.spell == newSpell and IsPlayerSpell(r.talent) then
                        entry.cd = r.reducedCD
                        break
                    end
                end
            end
        end

        CKYN_UI_Refresh()
    end

    ClearInspectPlayer()
    inspectPending = false
    ProcessInspectQueue()
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
        -- 스펙 교정 (예: 헌터 Counter Shot → Muzzle 자동 전환)
        entry.spellID   = spellID
        entry.cd        = data.cd
        entry.endTime   = now + data.cd
        entry.confirmed = true
    else
        CKYN.roster[unitID] = {
            name      = name,
            class     = classFile or data.class or "",
            spellID   = spellID,
            cd        = data.cd,
            endTime   = now + data.cd,
            confirmed = true,
            specID    = nil,
        }
    end

    CKYN_UI_Refresh()
end

-- ================================================================
-- M+ 상태 관리
-- ================================================================
local function OnEnterMythicPlus()
    if CKYN.inMythicPlus then return end
    CKYN.inMythicPlus = true
    BuildRoster()
    CKYN_UI_Show()
    -- 로스터 구성 후 약간 지연해서 Inspect 시작 (UnitClass 정착 대기)
    C_Timer.After(1.5, InspectAllParty)
end

local function OnLeaveMythicPlus()
    if not CKYN.inMythicPlus then return end
    CKYN.inMythicPlus = false
    CKYN.roster = {}
    inspectQueue = {}
    inspectPending = false
    CKYN_UI_Hide()
end

-- ================================================================
-- TEST MODE
-- /ckn test → 모든 UI 상태를 한눈에 확인할 수 있는 가짜 파티 데이터 주입
-- ================================================================
local TEST_DATA = {
    -- 상태별 대표 케이스 5종
    { name = "Kickmaster",   class = "WARRIOR",     spellID = 6552,   cd = 15,  endTime = 0,   confirmed = true,  noKick = false, apiLimit = false }, -- READY
    { name = "SlowKicker",   class = "ROGUE",        spellID = 1766,   cd = 15,  endTime = 8,   confirmed = true,  noKick = false, apiLimit = false }, -- 쿨 중 (8초 후 기준)
    { name = "MaybeKick",    class = "PALADIN",      spellID = 96231,  cd = 15,  endTime = 0,   confirmed = false, noKick = false, apiLimit = false }, -- 특성 미확인
    { name = "HolyNoKick",   class = "PRIEST",       spellID = nil,    cd = 0,   endTime = 0,   confirmed = true,  noKick = true,  apiLimit = false }, -- 차단 없음
    { name = "Demonlock",    class = "WARLOCK",      spellID = nil,    cd = 0,   endTime = 0,   confirmed = false, noKick = false, apiLimit = true  }, -- 추적 불가
}

local function RunTestMode()
    CKYN.roster = {}
    local now   = GetTime()

    -- 본인 실제 데이터
    local myName = GetShortName("player")
    if myName then
        local spellID, confirmed = ResolvePlayerSpell()
        local cd = 15
        if spellID then
            local data = CKYN_SPELLS[spellID]
            cd = data and data.cd or 15
        end
        CKYN.roster["player"] = {
            name      = myName .. " (나)",
            class     = select(2, UnitClass("player")) or "WARRIOR",
            spellID   = spellID,
            cd        = cd,
            endTime   = 0,
            confirmed = confirmed,
            noKick    = (spellID == nil and confirmed),
            apiLimit  = false,
            specID    = nil,
        }
    end

    -- 가짜 파티원 주입 (fakeN 키 사용 — party1~4와 겹치지 않게)
    for i, d in ipairs(TEST_DATA) do
        local key = "fake" .. i
        CKYN.roster[key] = {
            name      = d.name,
            class     = d.class,
            spellID   = d.spellID,
            cd        = d.cd,
            endTime   = d.endTime > 0 and (now + d.endTime) or 0,
            confirmed = d.confirmed,
            noKick    = d.noKick,
            apiLimit  = d.apiLimit,
            specID    = nil,
        }
    end

    CKYN_UI_ForceShow()
    Log("|cffaaaaaa테스트 모드 — 실제 M+ 데이터가 아닙니다|r")
end

-- ================================================================
-- COMMANDS
-- /ckn          → 패널 토글
-- /ckn test     → 테스트 모드 (솔로 UI 확인)
-- /ckn config   → 설정창 열기
-- /ckn reset    → 쿨타임 초기화
-- /ckn reload   → 로스터 재스캔 + 재검사
-- ================================================================
SLASH_CKYN1 = "/ckn"
SlashCmdList["CKYN"] = function(msg)
    local arg = msg and msg:lower():match("^%s*(%S*)") or ""
    if arg == "test" then
        RunTestMode()
    elseif arg == "config" then
        if CKYN_Options_Open then CKYN_Options_Open() end
    elseif arg == "reset" then
        for _, entry in pairs(CKYN.roster) do
            entry.endTime = 0
        end
        CKYN_UI_Refresh()
        Log("쿨타임 초기화")
    elseif arg == "reload" then
        BuildRoster()
        C_Timer.After(0.5, InspectAllParty)
        Log("로스터 재스캔 + 재검사")
    else
        CKYN_UI_Toggle()
    end
end

-- ================================================================
-- INIT
-- ================================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("GROUP_ROSTER_UPDATE")
loader:RegisterEvent("INSPECT_READY")
loader:RegisterEvent("ZONE_CHANGED_NEW_AREA")

-- M+ 전용 이벤트
loader:RegisterEvent("CHALLENGE_MODE_START")
loader:RegisterEvent("CHALLENGE_MODE_COMPLETED")
loader:RegisterEvent("CHALLENGE_MODE_RESET")

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end
        CKYNdb = CKYNdb or {}

        local defaults = {
            bgAlpha    = 0.85,
            barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
            rowHeight  = 28,
            barHeight  = 14,
            iconSize   = 24,
            showIcon   = true,
            fontSize   = 11,
            rowSpacing = 2,
            tooltipOn  = true,
            autoShow   = true,
        }
        for k, v in pairs(defaults) do
            if CKYNdb[k] == nil then CKYNdb[k] = v end
        end

        CKYN_UI_Init()
        Log("v" .. VERSION .. "  |cff888888/ckn|r")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 로딩 후 M+ 여부 확인
        C_Timer.After(1.5, function()
            if IsInMythicPlus() then
                OnEnterMythicPlus()
            else
                BuildRoster()  -- 로스터는 항상 구성 (수동 /ckn 토글 대비)
            end
        end)

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.5, function()
            if IsInMythicPlus() then
                OnEnterMythicPlus()
            else
                OnLeaveMythicPlus()
            end
        end)

    elseif event == "GROUP_ROSTER_UPDATE" then
        C_Timer.After(0.5, function()
            BuildRoster()
            if CKYN.inMythicPlus then
                C_Timer.After(1, InspectAllParty)
            end
        end)

    elseif event == "CHALLENGE_MODE_START" then
        OnEnterMythicPlus()

    elseif event == "CHALLENGE_MODE_COMPLETED" or
           event == "CHALLENGE_MODE_RESET" then
        -- 완료/리셋 후 잠시 유지하다가 숨기기 (결과 확인 가능하도록)
        C_Timer.After(3, function()
            if not IsInMythicPlus() then
                OnLeaveMythicPlus()
            end
        end)

    elseif event == "INSPECT_READY" then
        local guid = ...
        OnInspectReady(guid)
    end
end)

-- 스킬 사용 감지 (별도 프레임 — taint 방지)
local castFrame = CreateFrame("Frame")
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED",
    "player", "party1", "party2", "party3", "party4")
castFrame:SetScript("OnEvent", function(_, _, unitID, _, spellID)
    OnUnitSpellCast(unitID, spellID)
end)
