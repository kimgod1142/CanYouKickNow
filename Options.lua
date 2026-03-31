-- Options.lua
-- CanYouKickNow 설정창  (/ckn config)

local OPT_W       = 350
local PAD         = 14
local TITLE_H     = 30
local POPUP_ROW_H = 28
local MAX_POPUP_H = 240

-- ================================================================
-- 텍스처 목록 (LibSharedMedia 있으면 확장)
-- ================================================================
local function GetTextureList()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local list = {}
        for name, path in pairs(LSM:HashTable("statusbar")) do
            list[#list + 1] = { name = name, path = path }
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end
    return {
        { name = "기본 (Default)", path = "Interface\\TargetingFrame\\UI-StatusBar"                },
        { name = "레이드 HP",      path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"                 },
        { name = "플랫 (Flat)",    path = "Interface\\Buttons\\WHITE8x8"                           },
        { name = "스킬바",         path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    }
end

-- ================================================================
-- 옵션 프레임
-- ================================================================
local opt = CreateFrame("Frame", "CKYN_OptionsFrame", UIParent, "BackdropTemplate")
opt:SetSize(OPT_W, 100)
opt:SetPoint("CENTER")
opt:SetFrameStrata("DIALOG")
opt:SetMovable(true)
opt:EnableMouse(true)
opt:RegisterForDrag("LeftButton")
opt:SetScript("OnDragStart", opt.StartMoving)
opt:SetScript("OnDragStop",  opt.StopMovingOrSizing)
opt:Hide()

if opt.SetBackdrop then
    opt:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    opt:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
    opt:SetBackdropBorderColor(0.2, 0.8, 1.0, 1)
end

tinsert(UISpecialFrames, "CKYN_OptionsFrame")  -- ESC로 닫기

local titleFs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleFs:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, -9)
titleFs:SetText("|cff00ff99Can|r|cffffffff You|r|cffff4444Kick|r|cffffffff Now?|r  " ..
                (GetLocale() == "koKR" and "설정" or "Settings"))

local closeBtn = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("TOPRIGHT", opt, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() opt:Hide() end)

opt:SetScript("OnHide", function()
    if _G["CKYN_TexPopup"] then _G["CKYN_TexPopup"]:Hide() end
    if _G["CKYN_TexCatch"]  then _G["CKYN_TexCatch"]:Hide()  end
    -- 설정창 닫힐 때 M+ 밖이면 테스트 패널도 같이 닫기
    if not CKYN.inMythicPlus then
        CKYN.roster = {}
        if CKYN_UI_Hide then CKYN_UI_Hide() end
    end
end)

-- ================================================================
-- Refresh 제어: syncing 플래그 + 80ms throttle
-- ================================================================
local syncing      = false
local refreshTimer = nil

local function ApplyAndRefresh()
    if syncing then return end
    if refreshTimer then refreshTimer:Cancel() end
    refreshTimer = C_Timer.NewTimer(0.08, function()
        refreshTimer = nil
        if CKYN_UI_ApplySettings then CKYN_UI_ApplySettings(true) end
    end)
end

-- ================================================================
-- 텍스처 드롭다운 팝업
-- ================================================================
local texPopup = CreateFrame("Frame", "CKYN_TexPopup", UIParent, "BackdropTemplate")
texPopup:SetFrameStrata("TOOLTIP")
texPopup:Hide()
if texPopup.SetBackdrop then
    texPopup:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    texPopup:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
    texPopup:SetBackdropBorderColor(0.2, 0.8, 1.0, 1)
end

local texScroll = CreateFrame("ScrollFrame", nil, texPopup)
texScroll:SetPoint("TOPLEFT",     texPopup, "TOPLEFT",     4, -4)
texScroll:SetPoint("BOTTOMRIGHT", texPopup, "BOTTOMRIGHT", -4,  4)
texScroll:EnableMouseWheel(true)
texScroll:SetScript("OnMouseWheel", function(self, delta)
    local max    = self:GetVerticalScrollRange()
    local scroll = math.max(0, math.min(max, self:GetVerticalScroll() - delta * POPUP_ROW_H))
    self:SetVerticalScroll(scroll)
end)

local texContent = CreateFrame("Frame", nil, texScroll)
texScroll:SetScrollChild(texContent)

local texCatch = CreateFrame("Frame", "CKYN_TexCatch", UIParent)
texCatch:SetAllPoints(UIParent)
texCatch:SetFrameStrata("FULLSCREEN")
texCatch:EnableMouse(true)
texCatch:Hide()
texCatch:SetScript("OnMouseDown", function()
    texPopup:Hide()
    texCatch:Hide()
end)

local texList       = {}
local selHighlights = {}
local texIdx        = 1
local texBtn

local function RebuildTexPopup()
    for _, child in pairs({ texContent:GetChildren() }) do child:Hide() end
    texList       = GetTextureList()
    selHighlights = {}

    local cur = CKYNdb and CKYNdb.barTexture or ""
    texIdx = 1
    for i, t in ipairs(texList) do
        if t.path == cur then texIdx = i; break end
    end

    local w = texPopup:GetWidth() - 8
    texContent:SetSize(w, #texList * POPUP_ROW_H)

    for i, tex in ipairs(texList) do
        local row = CreateFrame("Button", nil, texContent)
        row:SetHeight(POPUP_ROW_H)
        row:SetPoint("TOPLEFT",  texContent, "TOPLEFT",  0, -(i - 1) * POPUP_ROW_H)
        row:SetPoint("TOPRIGHT", texContent, "TOPRIGHT",  0, 0)

        local selBg = row:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints()
        selBg:SetColorTexture(0.2, 0.8, 1.0, 0.15)
        selBg:SetShown(i == texIdx)
        selHighlights[i] = selBg

        local hlTex = row:CreateTexture(nil, "HIGHLIGHT")
        hlTex:SetAllPoints()
        hlTex:SetColorTexture(1, 1, 1, 0.08)

        local preview = CreateFrame("StatusBar", nil, row)
        preview:SetSize(80, 14)
        preview:SetPoint("LEFT", row, "LEFT", 4, 0)
        preview:SetStatusBarTexture(tex.path)
        preview:SetMinMaxValues(0, 1)
        preview:SetValue(0.65)
        preview:SetStatusBarColor(0.0, 1.0, 0.6, 1)

        local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFs:SetPoint("LEFT", preview, "RIGHT", 8, 0)
        nameFs:SetText(tex.name)

        row:SetScript("OnClick", function()
            texIdx = i
            if texBtn then texBtn:SetText(tex.name .. "  ▼") end
            if CKYNdb then CKYNdb.barTexture = tex.path end
            for j, hl in ipairs(selHighlights) do hl:SetShown(j == i) end
            texPopup:Hide()
            texCatch:Hide()
            ApplyAndRefresh()
        end)
    end

    local popupH = math.min(#texList * POPUP_ROW_H + 8, MAX_POPUP_H)
    texPopup:SetHeight(popupH)
    local scrollTo = math.max(0, (texIdx - 1) * POPUP_ROW_H - math.floor(MAX_POPUP_H / 2))
    texScroll:SetVerticalScroll(scrollTo)
end

-- ================================================================
-- 레이아웃 헬퍼
-- ================================================================
local yPos = -(TITLE_H + 4)

local function AddHeader(text)
    yPos = yPos - 8
    local fs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
    fs:SetText("|cff00ccff" .. text .. "|r")
    yPos = yPos - 16
    local line = opt:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.2, 0.8, 1.0, 0.4)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  opt, "TOPLEFT",  PAD,  yPos)
    line:SetPoint("TOPRIGHT", opt, "TOPRIGHT", -PAD, yPos)
    yPos = yPos - 10
end

local sliderRefs = {}
local function AddSlider(label, minVal, maxVal, step, key, fmt)
    local slider = CreateFrame("Slider", "CKYN_Opt_"..key, opt, "OptionsSliderTemplate")
    slider:SetWidth(OPT_W - PAD * 2 - 16)
    slider:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD + 8, yPos)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))

    local function Sync(val)
        slider.Text:SetText(label .. ": " .. string.format(fmt, val))
    end

    slider:SetScript("OnValueChanged", function(self, val)
        Sync(val)
        if CKYNdb then CKYNdb[key] = val end
        ApplyAndRefresh()
    end)

    sliderRefs[key] = { widget = slider, sync = Sync }
    yPos = yPos - 46
    return slider
end

local checkRefs = {}
local function AddCheckbox(label, key, defaultVal)
    local cb = CreateFrame("CheckButton", "CKYN_Opt_"..key, opt, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos + 3)
    cb.text:SetText(label)
    cb.text:SetFontObject(GameFontNormalSmall)
    cb:SetScript("OnClick", function(self)
        if CKYNdb then CKYNdb[key] = self:GetChecked() end
        ApplyAndRefresh()
    end)
    checkRefs[key] = { widget = cb, default = defaultVal }
    yPos = yPos - 28
    return cb
end

local function AddDropdownBtn(label, getTextFn, onClickFn)
    local lbl = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
    lbl:SetText(label)
    yPos = yPos - 18

    local btn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
    btn:SetWidth(OPT_W - PAD * 2 - 4)
    btn:SetHeight(22)
    btn:SetText(getTextFn() .. "  ▼")
    btn:SetScript("OnClick", onClickFn)
    yPos = yPos - 28
    return btn
end

-- ================================================================
-- 외관 섹션
-- ================================================================
AddHeader("외관")
AddSlider("배경 투명도", 0.1, 1.0, 0.05, "bgAlpha",    "%.2f")
AddSlider("행 높이",     20,  68,  1,    "rowHeight",  "%d px")
AddSlider("바 두께",     4,   68,  1,    "barHeight",  "%d px")
AddSlider("아이콘 크기", 14,  58,  1,    "iconSize",   "%d px")
AddSlider("폰트 크기",   8,   28,  1,    "fontSize",   "%d")
AddSlider("행 간격",     0,   24,  1,    "rowSpacing", "%d px")

texBtn = AddDropdownBtn("바 텍스처",
    function()
        local cur  = CKYNdb and CKYNdb.barTexture or ""
        local list = GetTextureList()
        for _, t in ipairs(list) do
            if t.path == cur then return t.name end
        end
        return "선택..."
    end,
    function(self)
        if texPopup:IsShown() then
            texPopup:Hide(); texCatch:Hide()
        else
            RebuildTexPopup()
            texPopup:ClearAllPoints()
            texPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            texPopup:SetWidth(self:GetWidth())
            texContent:SetWidth(self:GetWidth() - 8)
            texPopup:Show(); texPopup:Raise()
            texCatch:SetFrameLevel(texPopup:GetFrameLevel() - 1)
            texCatch:Show()
        end
    end
)

-- ================================================================
-- 기능 섹션
-- ================================================================
AddHeader("기능")
AddCheckbox("아이콘 표시",             "showIcon",   true)
AddCheckbox("아이콘 마우스오버 툴팁",  "tooltipOn",  true)
AddCheckbox("M+ 진입 시 자동 표시",    "autoShow",   true)

-- ================================================================
-- 프레임 최종 높이 확정
-- ================================================================
opt:SetHeight(math.abs(yPos) + PAD + 10)

-- ================================================================
-- 공개 함수: 창 열기
-- ================================================================
function CKYN_Options_Open()
    if not CKYNdb then opt:Show(); return end

    syncing = true

    for key, ref in pairs(sliderRefs) do
        local val = CKYNdb[key]
        if val ~= nil then
            ref.widget:SetValue(val)
            ref.sync(val)
        end
    end
    for key, ref in pairs(checkRefs) do
        local val = CKYNdb[key]
        if val == nil then val = ref.default end
        ref.widget:SetChecked(val)
    end

    syncing = false

    local curTex  = CKYNdb.barTexture or ""
    local texName = "선택..."
    for _, t in ipairs(GetTextureList()) do
        if t.path == curTex then texName = t.name; break end
    end
    texBtn:SetText(texName .. "  ▼")

    opt:Show()
    opt:Raise()

    -- 설정창 열릴 때 테스트 모드 자동 실행 (M+ 밖일 때만)
    if not CKYN.inMythicPlus then
        C_Timer.After(0.05, function()
            SlashCmdList["CKYN"]("test")
        end)
    end
end
