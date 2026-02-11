-- Blood Pact - Personal Dashboard
-- Displays account-wide statistics: stat cards + character list

BloodPact_PersonalDashboard = {}

local panel = nil
local charRows = {}

-- ============================================================
-- Construction
-- ============================================================

function BloodPact_PersonalDashboard:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panel:Hide()

    self:CreateStatCards()
    self:CreateCharacterList()
    self:CreateActionButtons()

    -- Register with main frame as tab 1 (Personal)
    BloodPact_MainFrame:RegisterTabPanel(1, panel)

    panel.Refresh = function() BloodPact_PersonalDashboard:Refresh() end
    BloodPact_PersonalDashboard.panel = panel
end

function BloodPact_PersonalDashboard:CreateStatCards()
    -- 4 stat cards in a 2x2 grid
    local cardW = 255
    local cardH = 70
    local padX  = 16
    local padY  = 12

    local cardDefs = {
        {key = "deaths",  label = "Total Deaths"},
        {key = "level",   label = "Highest Level"},
        {key = "gold",    label = "Total Gold Lost"},
        {key = "xp",      label = "Total XP Lost"},
    }

    panel.statCards = {}
    for i, def in ipairs(cardDefs) do
        local col = math.mod(i - 1, 2)
        local row = math.floor((i - 1) / 2)
        local card = self:CreateStatCard(
            panel, def.label,
            padX + col * (cardW + 10),
            -(padY + row * (cardH + 10))
        )
        card:SetWidth(cardW)
        card:SetHeight(cardH)
        panel.statCards[def.key] = card
    end
end

function BloodPact_PersonalDashboard:CreateStatCard(parent, labelText, offsetX, offsetY)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", offsetX, offsetY)
    BP_ApplyPanelBackdrop(card)

    local label = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    label:SetText(labelText)
    label:SetPoint("TOP", card, "TOP", 0, -8)
    label:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))
    card.label = label

    local value = BP_CreateFontString(card, 20)
    value:SetText("0")
    value:SetPoint("CENTER", card, "CENTER", 0, 2)
    value:SetTextColor(1, 1, 1, 1)
    card.value = value

    return card
end

function BloodPact_PersonalDashboard:CreateCharacterList()
    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -180)
    listFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -180)
    listFrame:SetHeight(140)
    BP_ApplyPanelBackdrop(listFrame)

    local header = BP_CreateFontString(listFrame, BP_FONT_SIZE_SMALL)
    header:SetText("Characters")
    header:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, -6)
    header:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    local divider = BP_CreateDivider(listFrame, 500)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)

    -- Scroll frame for character rows
    local scrollFrame = CreateFrame("ScrollFrame", "BPPersonalCharScroll", listFrame)
    scrollFrame:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 4)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local delta = arg1
        local current = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(math.max(0, current - delta * 20))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(1)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    panel.charListFrame  = listFrame
    panel.charScrollFrame = scrollFrame
    panel.charScrollChild = scrollChild
end

function BloodPact_PersonalDashboard:CreateActionButtons()
    local btnTimeline = BP_CreateButton(panel, "View Timeline", 100, 22)
    btnTimeline:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 8)
    btnTimeline:SetScript("OnClick", function()
        BloodPact_MainFrame:SwitchTab(1)  -- Switch to personal tab (timeline sub-view)
        BloodPact_PersonalTimeline:Show()
    end)

    panel.btnTimeline = btnTimeline
end

-- ============================================================
-- Refresh / Data Update
-- ============================================================

function BloodPact_PersonalDashboard:Refresh()
    if not panel then return end

    -- Update stat cards
    local deaths  = BloodPact_DeathDataManager:GetTotalDeaths()
    local level   = BloodPact_DeathDataManager:GetHighestLevel()
    local copper  = BloodPact_DeathDataManager:GetTotalCopperLost()
    local xp      = BloodPact_DeathDataManager:GetTotalXPLost()

    if panel.statCards.deaths then
        panel.statCards.deaths.value:SetText(tostring(deaths))
        -- Color intensity based on death count
        if deaths == 0 then
            panel.statCards.deaths.value:SetTextColor(0.8, 0.8, 0.8, 1)
        elseif deaths < 5 then
            panel.statCards.deaths.value:SetTextColor(1.0, 0.7, 0.3, 1)
        else
            panel.statCards.deaths.value:SetTextColor(1.0, 0.3, 0.3, 1)
        end
    end

    if panel.statCards.level then
        panel.statCards.level.value:SetText(tostring(level))
        panel.statCards.level.value:SetTextColor(0.4, 1.0, 0.4, 1)
    end

    if panel.statCards.gold then
        panel.statCards.gold.value:SetText(BloodPact_DeathDataManager:FormatCopper(copper))
        panel.statCards.gold.value:SetTextColor(1.0, 0.84, 0.0, 1)
    end

    if panel.statCards.xp then
        panel.statCards.xp.value:SetText(self:FormatXP(xp))
        panel.statCards.xp.value:SetTextColor(0.8, 0.8, 1.0, 1)
    end

    -- Rebuild character list
    self:RefreshCharacterList()
end

function BloodPact_PersonalDashboard:RefreshCharacterList()
    -- Clear existing rows
    for _, row in ipairs(charRows) do
        row:Hide()
        row:SetParent(nil)
    end
    charRows = {}

    if not panel.charScrollChild then return end

    local summaries = BloodPact_DeathDataManager:GetCharacterSummaries()
    local rowHeight = 24
    local yOffset = 0

    -- Compute display names for multiple instances of same character (e.g. "Bob", "Bob #2")
    local nameCounts = {}
    for i, summary in ipairs(summaries) do
        local n = summary.characterName or "?"
        nameCounts[n] = (nameCounts[n] or 0) + 1
        summary.displayName = (nameCounts[n] > 1) and (n .. " #" .. tostring(nameCounts[n])) or n
    end

    for i, summary in ipairs(summaries) do
        local row = self:CreateCharRow(panel.charScrollChild, summary, yOffset)
        table.insert(charRows, row)
        yOffset = yOffset - rowHeight
    end

    -- Update scroll child height
    panel.charScrollChild:SetHeight(math.max(1, -yOffset))
end

function BloodPact_PersonalDashboard:CreateCharRow(parent, summary, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

    -- Character name (with #2, #3 suffix when multiple instances of same name)
    local nameText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    nameText:SetText(summary.displayName or summary.characterName)
    nameText:SetPoint("LEFT", row, "LEFT", 4, 0)

    -- Highest level
    local levelText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    levelText:SetText("Lvl " .. tostring(summary.highestLevel))
    levelText:SetPoint("LEFT", row, "LEFT", 130, 0)
    levelText:SetTextColor(0.4, 1.0, 0.4, 1)

    -- Status
    local statusText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    if summary.deathCount > 0 then
        statusText:SetText("DEAD")
        statusText:SetTextColor(0.8, 0.3, 0.3, 1)
    else
        statusText:SetText("ALIVE")
        statusText:SetTextColor(BP_Color(BLOODPACT_COLORS.ALIVE))
    end
    statusText:SetPoint("LEFT", row, "LEFT", 200, 0)

    -- View Timeline button
    local viewBtn = BP_CreateButton(row, "Timeline", 70, 18)
    viewBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    local charName = summary.characterName
    local instanceID = summary.characterInstanceID
    viewBtn:SetScript("OnClick", function()
        BloodPact_PersonalTimeline:ShowForCharacter(charName, instanceID)
    end)

    return row
end

function BloodPact_PersonalDashboard:FormatXP(xp)
    if xp >= 1000000 then
        return string.format("%.1fM", xp / 1000000)
    elseif xp >= 1000 then
        return string.format("%.1fk", xp / 1000)
    else
        return tostring(xp)
    end
end

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_PersonalDashboard:Initialize()
    -- Will be called after main frame is created
    local content = BloodPact_MainFrame:GetContentFrame()
    if content then
        self:Create(content)
    end
end
