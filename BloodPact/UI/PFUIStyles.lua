-- Blood Pact - PFUI Style Integration
-- Detects PFUI presence and provides consistent style constants with fallback

-- Detect PFUI
local PFUI_PRESENT = (pfUI ~= nil) or (pfUIConfig ~= nil)

-- Font path
if PFUI_PRESENT then
    BP_FONT = "Interface\\AddOns\\pfUI\\fonts\\homespun.ttf"
else
    BP_FONT = "Fonts\\FRIZQT__.TTF"
end

BP_FONT_SIZE_LARGE  = 14
BP_FONT_SIZE_MEDIUM = 11
BP_FONT_SIZE_SMALL  = 9

-- Backdrop configuration
if PFUI_PRESENT then
    BP_BACKDROP = {
        bgFile   = "Interface\\AddOns\\pfUI\\img\\panel",
        edgeFile = "Interface\\AddOns\\pfUI\\img\\border",
        tile     = false,
        tileSize = 8,
        edgeSize = 8,
        insets   = {left = 3, right = 3, top = 3, bottom = 3}
    }
    BP_BACKDROP_DARK = {
        bgFile   = "Interface\\AddOns\\pfUI\\img\\panel",
        edgeFile = "Interface\\AddOns\\pfUI\\img\\border",
        tile     = false,
        tileSize = 8,
        edgeSize = 8,
        insets   = {left = 3, right = 3, top = 3, bottom = 3}
    }
else
    BP_BACKDROP = {
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = {left = 3, right = 3, top = 3, bottom = 3}
    }
    BP_BACKDROP_DARK = BP_BACKDROP
end

-- Color helpers: unpack as r, g, b
function BP_Color(colorTable)
    return colorTable[1], colorTable[2], colorTable[3]
end

-- Apply standard backdrop to a frame
function BP_ApplyBackdrop(frame, dark)
    if dark then
        frame:SetBackdrop(BP_BACKDROP_DARK)
        frame:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
    else
        frame:SetBackdrop(BP_BACKDROP)
        frame:SetBackdropColor(0.15, 0.15, 0.15, 0.95)
    end
    frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
end

-- Apply panel backdrop (slightly lighter)
function BP_ApplyPanelBackdrop(frame)
    frame:SetBackdrop(BP_BACKDROP)
    frame:SetBackdropColor(0.18, 0.18, 0.18, 0.9)
    frame:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
end

-- Create a standard font string
function BP_CreateFontString(parent, size, layer)
    layer = layer or "OVERLAY"
    size = size or BP_FONT_SIZE_MEDIUM
    local fs = parent:CreateFontString(nil, layer)
    fs:SetFont(BP_FONT, size, "OUTLINE")
    fs:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_PRIMARY))
    return fs
end

-- Create a PFUI-styled button
function BP_CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width or 80)
    btn:SetHeight(height or 20)
    BP_ApplyBackdrop(btn)
    btn:SetBackdropColor(0.20, 0.20, 0.20, 1)
    btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    local label = BP_CreateFontString(btn, BP_FONT_SIZE_SMALL)
    label:SetText(text or "")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.label = label

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.28, 0.28, 0.28, 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.20, 0.20, 0.20, 1)
    end)

    return btn
end

-- Create a simple divider line
function BP_CreateDivider(parent, width)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetWidth(width or 200)
    line:SetTexture(0.3, 0.3, 0.3, 0.8)
    return line
end

-- Get item quality color
function BP_GetQualityColor(quality)
    if quality == 5 then return BP_Color(BLOODPACT_COLORS.QUALITY_LEGENDARY)
    elseif quality == 4 then return BP_Color(BLOODPACT_COLORS.QUALITY_EPIC)
    elseif quality == 3 then return BP_Color(BLOODPACT_COLORS.QUALITY_RARE)
    elseif quality == 2 then return BP_Color(BLOODPACT_COLORS.QUALITY_UNCOMMON)
    else return BP_Color(BLOODPACT_COLORS.QUALITY_COMMON)
    end
end
