-- UI.lua
-- 차단기 쿨타임 패널
-- 레이아웃: [플레이어명] [스킬아이콘] [쿨타임바 or READY]
--
-- ── 공개 API ────────────────────────────────────────────────────
--  CKYN_UI_Init()      로그인 시 저장된 위치·크기 복원
--  CKYN_UI_Refresh()   현재 roster 기반 패널 갱신 (항상 동작, 리더 체크 없음)
--  CKYN_UI_Toggle()    패널 열기/닫기 토글
--  CKYN_UI_Show()      패널 열기
--  CKYN_UI_Hide()      패널 닫기
-- ────────────────────────────────────────────────────────────────

local PANEL_W  = 280
local NAME_W   = 80
local ICON_SZ  = 24
local ROW_H    = 28
local BAR_H    = 14
local PAD      = 8
local TITLE_H  = 22

local MIN_W = NAME_W + ICON_SZ + PAD * 2 + 80
local MIN_H = TITLE_H + PAD * 2

local CLASS_COLORS = {
    WARRIOR      = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN      = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER       = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE        = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST       = { r = 1.00, g = 1.00, b = 1.00 },
    DEATHKNIGHT  = { r = 0.77, g = 0.12, b = 0.23 },
    SHAMAN       = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE         = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK      = { r = 0.58, g = 0.51, b = 0.79 },
    MONK         = { r = 0.00, g = 1.00, b = 0.60 },
    DRUID        = { r = 1.00, g = 0.49, b = 0.04 },
    DEMONHUNTER  = { r = 0.64, g = 0.19, b = 0.79 },
    EVOKER       = { r = 0.20, g = 0.58, b = 0.50 },
}

local function GetClassColor(classFile)
    local cc = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
            or CLASS_COLORS[classFile]
    if cc then return cc.r, cc.g, cc.b end
    return 0.6, 0.6, 0.6
end

-- ================================================================
-- 패널 프레임
-- ================================================================
local panel = CreateFrame("Frame", "CKYN_Panel", UIParent, "BackdropTemplate")
panel:SetWidth(PANEL_W)
panel:SetHeight(TITLE_H + PAD)
panel:SetPoint("CENTER", UIParent, "CENTER", -500, 0)
panel:SetFrameStrata("MEDIUM")
panel:SetMovable(true)
panel:SetResizable(true)
panel:SetResizeBounds(MIN_W, MIN_H)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()

if panel.SetBackdrop then
    panel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.04, 0.04, 0.08, 0.85)
    panel:SetBackdropBorderColor(0.2, 0.8, 1.0, 1)   -- 민트/청록 계열
end

panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if CKYNdb then
        local pt, _, rpt, x, y = self:GetPoint()
        CKYNdb.panelPos = { pt = pt, rpt = rpt, x = x, y = y }
    end
end)
panel:SetScript("OnSizeChanged", function(self, w, h)
    if CKYNdb then CKYNdb.panelSize = { w = w, h = h } end
end)

-- ================================================================
-- 리사이즈 핸들
-- ================================================================
local function MakeHandle(sizeDir)
    local h = CreateFrame("Frame", nil, panel)
    h:SetFrameLevel(panel:GetFrameLevel() + 5)
    h:EnableMouse(true)
    h:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then panel:StartSizing(sizeDir) end
    end)
    h:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing()
        if CKYNdb then
            CKYNdb.panelSize = { w = panel:GetWidth(), h = panel:GetHeight() }
        end
    end)
    return h
end

local hRight  = MakeHandle("RIGHT")
hRight:SetPoint("TOPRIGHT",    panel, "TOPRIGHT",    0,  -TITLE_H)
hRight:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0,   6)
hRight:SetWidth(6)

local hBottom = MakeHandle("BOTTOM")
hBottom:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",   6, 0)
hBottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 0)
hBottom:SetHeight(6)

local hCorner = MakeHandle("BOTTOMRIGHT")
hCorner:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
hCorner:SetSize(10, 10)
local grip = hCorner:CreateTexture(nil, "OVERLAY")
grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", hCorner, "BOTTOMRIGHT", 0, 0)
hCorner:SetScript("OnEnter", function() grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight") end)
hCorner:SetScript("OnLeave", function() grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up") end)

-- ================================================================
-- 타이틀
-- ================================================================
local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -5)
titleText:SetText("|cff00ff99Can|r|cffffffff You|r|cffff4444Kick|r|cffffffff Now?|r  |cff888888/ckn|r")

local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetSize(16, 16)
closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() panel:Hide() end)

-- ================================================================
-- 행 풀
-- ================================================================
local rowPool    = {}
local activeRows = {}

local function MakeRow(parent)
    local row  = {}
    local font = GameFontNormalSmall:GetFont()

    row.frame = CreateFrame("Frame", nil, parent)
    row.frame:SetHeight(ROW_H)

    local nameBg = row.frame:CreateTexture(nil, "BACKGROUND")
    nameBg:SetColorTexture(0, 0, 0, 0.3)
    nameBg:SetPoint("TOPLEFT",    row.frame, "TOPLEFT",    0, 0)
    nameBg:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
    nameBg:SetWidth(NAME_W)

    row.nameText = row.frame:CreateFontString(nil, "OVERLAY")
    row.nameText:SetFont(font, 11)
    row.nameText:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
    row.nameText:SetWidth(NAME_W - 6)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.icon = row.frame:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SZ, ICON_SZ)
    row.icon:SetPoint("LEFT", row.frame, "LEFT", NAME_W + 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local iconHover = CreateFrame("Frame", nil, row.frame)
    iconHover:SetAllPoints(row.icon)
    iconHover:EnableMouse(true)
    iconHover:SetScript("OnEnter", function(self)
        if not row.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(row.spellID)
        GameTooltip:Show()
    end)
    iconHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local barBg = row.frame:CreateTexture(nil, "BACKGROUND")
    barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    barBg:SetPoint("LEFT",  row.frame, "LEFT",  NAME_W + ICON_SZ + 12, -(ROW_H - BAR_H) / 2)
    barBg:SetPoint("RIGHT", row.frame, "RIGHT", 0,                     -(ROW_H - BAR_H) / 2)
    barBg:SetHeight(BAR_H)
    row.barBg = barBg

    local bar = CreateFrame("StatusBar", nil, row.frame)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetPoint("TOPLEFT",     barBg, "TOPLEFT",     1, -1)
    bar:SetPoint("BOTTOMRIGHT", barBg, "BOTTOMRIGHT", -1, 1)
    row.bar = bar

    row.cdText = bar:CreateFontString(nil, "OVERLAY")
    row.cdText:SetFont(font, 11)
    row.cdText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    row.cdText:SetJustifyH("RIGHT")

    -- "READY" 텍스트: 바 위에 중앙 정렬, 초록
    row.readyText = bar:CreateFontString(nil, "OVERLAY")
    row.readyText:SetFont(font, 11)
    row.readyText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    row.readyText:SetText("|cff00ff00▶ READY|r")
    row.readyText:Hide()

    return row
end

local function GetRow(parent)
    local row = table.remove(rowPool)
    if not row then row = MakeRow(parent) end
    row.frame:SetParent(parent)
    row.frame:Show()
    row.cdText:SetText("")
    row.cdText:Show()
    row.readyText:Hide()
    return row
end

local function ReleaseRow(row)
    row.frame:Hide()
    table.insert(rowPool, row)
end

-- ================================================================
-- OnUpdate: 매 프레임 바 + 텍스트 갱신
-- ================================================================
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function()
    if #activeRows == 0 then return end
    local now = GetTime()
    for _, row in ipairs(activeRows) do
        if row.endTime and row.endTime > now then
            -- 쿨타임 중
            local remain = row.endTime - now
            row.bar:SetValue(remain / (row.totalCD or 1))
            row.cdText:SetText(string.format("%.0fs", remain))
            row.cdText:SetTextColor(1, 0.4, 0.4, 1)
            row.cdText:Show()
            row.readyText:Hide()
        else
            -- 사용 가능
            row.bar:SetValue(0)
            row.cdText:Hide()
            row.readyText:Show()
        end
    end
end)

-- ================================================================
-- 내부: 행 재구성
-- ================================================================
local function RebuildRows()
    for _, row in ipairs(activeRows) do ReleaseRow(row) end
    activeRows = {}

    -- unitID 순서 고정: player 먼저, 이후 party1~4
    local unitOrder = { "player", "party1", "party2", "party3", "party4" }

    local rowH = ROW_H
    local gap  = 2
    local yOff = -(TITLE_H + 4)

    for _, unitID in ipairs(unitOrder) do
        local entry = CKYN.roster[unitID]
        if entry then
            local row       = GetRow(panel)
            local spellData = CKYN_SPELLS[entry.spellID]
            local r, g, b   = GetClassColor(entry.class)

            row.frame:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD,  yOff)
            row.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, yOff)

            row.nameText:SetText(string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, entry.name))
            row.bar:SetStatusBarColor(r, g, b, 0.7)
            row.icon:SetTexture(
                (spellData and spellData.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
            )

            row.spellID = entry.spellID
            row.totalCD = entry.cd
            row.endTime = entry.endTime or 0

            activeRows[#activeRows + 1] = row
            yOff = yOff - rowH - gap
        end
    end

    local count    = #activeRows
    local contentH = TITLE_H + (count * (rowH + gap)) + PAD
    MIN_H = math.max(TITLE_H + PAD * 2, contentH)
    panel:SetResizeBounds(MIN_W, MIN_H)
    if panel:GetHeight() < MIN_H then panel:SetHeight(MIN_H) end
end

-- ================================================================
-- 공개 API
-- ================================================================

-- 이벤트 핸들러용. 패널이 열려 있으면 갱신.
function CKYN_UI_Refresh()
    if panel:IsShown() then
        RebuildRows()
    end
end

-- 패널 열기/닫기 토글 (/ckn 기본 동작)
function CKYN_UI_Toggle()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
        RebuildRows()
    end
end

-- 강제 표시 (자동 표시용)
function CKYN_UI_Show()
    panel:Show()
    RebuildRows()
end

-- 패널 닫기
function CKYN_UI_Hide()
    panel:Hide()
end

-- 로그인 시 저장된 위치·크기 복원
function CKYN_UI_Init()
    if not CKYNdb then return end
    if CKYNdb.panelPos then
        local p = CKYNdb.panelPos
        panel:ClearAllPoints()
        panel:SetPoint(p.pt, UIParent, p.rpt, p.x, p.y)
    end
    if CKYNdb.panelSize then
        panel:SetSize(
            math.max(MIN_W, CKYNdb.panelSize.w),
            math.max(MIN_H, CKYNdb.panelSize.h)
        )
    end
end
