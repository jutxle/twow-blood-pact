-- Blood Pact - Pact Dashboard
-- Displays pact-level statistics and member roster

BloodPact_PactDashboard = {}

local panel = nil
local memberRows = {}

-- ============================================================
-- Construction
-- ============================================================

function BloodPact_PactDashboard:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panel:Hide()

    self:CreatePactHeader()
    self:CreateStatCards()
    self:CreateMemberList()
    self:CreateActionButtons()

    -- Register as tab 2 (Pact)
    BloodPact_MainFrame:RegisterTabPanel(2, panel)

    panel.Refresh = function() BloodPact_PactDashboard:Refresh() end
    BloodPact_PactDashboard.panel = panel
end

function BloodPact_PactDashboard:CreatePactHeader()
    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(44)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -4)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -4)
    BP_ApplyPanelBackdrop(header)

    panel.pactNameText = BP_CreateFontString(header, BP_FONT_SIZE_MEDIUM)
    panel.pactNameText:SetPoint("TOPLEFT", header, "TOPLEFT", 8, -6)
    panel.pactNameText:SetTextColor(1.0, 0.84, 0.0, 1)

    panel.joinCodeText = BP_CreateFontString(header, BP_FONT_SIZE_SMALL)
    panel.joinCodeText:SetPoint("TOPLEFT", panel.pactNameText, "BOTTOMLEFT", 0, -4)
    panel.joinCodeText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    panel.pactHeader = header
end

function BloodPact_PactDashboard:CreateStatCards()
    local cardW = 255
    local cardH = 60
    local padX  = 8
    local padY  = 8

    local cardDefs = {
        {key = "deaths",  label = "Total Deaths"},
        {key = "members", label = "Members"},
        {key = "level",   label = "Highest Level"},
        {key = "gold",    label = "Total Gold Lost"},
    }

    panel.statCards = {}
    for i, def in ipairs(cardDefs) do
        local col = math.mod(i - 1, 2)
        local row = math.floor((i - 1) / 2)
        local card = CreateFrame("Frame", nil, panel)
        card:SetWidth(cardW)
        card:SetHeight(cardH)
        card:SetPoint("TOPLEFT", panel, "TOPLEFT",
            padX + col * (cardW + 10),
            -(52 + padY + row * (cardH + 8)))
        BP_ApplyPanelBackdrop(card)

        local label = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
        label:SetText(def.label)
        label:SetPoint("TOP", card, "TOP", 0, -6)
        label:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        local value = BP_CreateFontString(card, 18)
        value:SetText("0")
        value:SetPoint("CENTER", card, "CENTER", 0, 2)
        value:SetTextColor(1, 1, 1, 1)

        card.value = value
        panel.statCards[def.key] = card
    end
end

function BloodPact_PactDashboard:CreateMemberList()
    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -200)
    listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 30)
    BP_ApplyPanelBackdrop(listFrame)

    local header = BP_CreateFontString(listFrame, BP_FONT_SIZE_SMALL)
    header:SetText("Pact Members")
    header:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, -6)
    header:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    local divider = BP_CreateDivider(listFrame, 500)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)

    local scrollFrame = CreateFrame("ScrollFrame", "BPPactMemberScroll", listFrame)
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

    panel.memberScrollFrame = scrollFrame
    panel.memberScrollChild = scrollChild
end

function BloodPact_PactDashboard:CreateActionButtons()
    local btnTimeline = BP_CreateButton(panel, "Pact Timeline", 100, 22)
    btnTimeline:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 4)
    btnTimeline:SetScript("OnClick", function()
        BloodPact_PactTimeline:Show()
    end)
end

-- ============================================================
-- Refresh
-- ============================================================

function BloodPact_PactDashboard:Refresh()
    if not panel then return end
    if not BloodPact_PactManager:IsInPact() then return end

    local pact = BloodPactAccountDB.pact

    -- Header
    if panel.pactNameText then
        panel.pactNameText:SetText("Pact: " .. (pact.pactName or "Unknown"))
    end
    if panel.joinCodeText then
        panel.joinCodeText:SetText("Join Code: " .. (pact.joinCode or "????????"))
    end

    -- Aggregate stats
    local allDeaths = BloodPact_DeathDataManager:GetAllPactDeaths()
    local totalDeaths = table.getn(allDeaths)

    local memberCount = 0
    local aliveCount  = 0
    local highestLevel = 0
    local totalCopper = 0

    if pact.members then
        for _, member in pairs(pact.members) do
            memberCount = memberCount + 1
            if member.isAlive then aliveCount = aliveCount + 1 end
            if (member.highestLevel or 0) > highestLevel then
                highestLevel = member.highestLevel
            end
        end
    end

    for _, death in ipairs(allDeaths) do
        totalCopper = totalCopper + (death.copperAmount or 0)
        if (death.level or 0) > highestLevel then
            highestLevel = death.level
        end
    end

    if panel.statCards.deaths then
        panel.statCards.deaths.value:SetText(tostring(totalDeaths))
        panel.statCards.deaths.value:SetTextColor(1.0, 0.3, 0.3, 1)
    end
    if panel.statCards.members then
        panel.statCards.members.value:SetText(tostring(memberCount) .. " (" .. tostring(aliveCount) .. " alive)")
        panel.statCards.members.value:SetTextColor(0.4, 1.0, 0.4, 1)
    end
    if panel.statCards.level then
        panel.statCards.level.value:SetText(tostring(highestLevel))
        panel.statCards.level.value:SetTextColor(0.4, 1.0, 0.4, 1)
    end
    if panel.statCards.gold then
        panel.statCards.gold.value:SetText(BloodPact_DeathDataManager:FormatCopper(totalCopper))
        panel.statCards.gold.value:SetTextColor(1.0, 0.84, 0.0, 1)
    end

    -- Rebuild member list
    self:RefreshMemberList()
end

function BloodPact_PactDashboard:RefreshMemberList()
    for _, row in ipairs(memberRows) do
        row:Hide()
        row:SetParent(nil)
    end
    memberRows = {}

    if not panel.memberScrollChild then return end
    if not BloodPactAccountDB.pact or not BloodPactAccountDB.pact.members then return end

    local rowHeight = 24
    local yOffset = 0

    for accountID, member in pairs(BloodPactAccountDB.pact.members) do
        local row = self:CreateMemberRow(panel.memberScrollChild, accountID, member, yOffset)
        table.insert(memberRows, row)
        yOffset = yOffset - rowHeight
    end

    panel.memberScrollChild:SetHeight(math.max(1, -yOffset))
end

function BloodPact_PactDashboard:CreateMemberRow(parent, accountID, member, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

    -- Status icon (text-based: ✓ or ☠)
    local statusIcon = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    if member.isAlive then
        statusIcon:SetText("✓")
        statusIcon:SetTextColor(BP_Color(BLOODPACT_COLORS.ALIVE))
    else
        statusIcon:SetText("☠")
        statusIcon:SetTextColor(BP_Color(BLOODPACT_COLORS.DECEASED))
    end
    statusIcon:SetPoint("LEFT", row, "LEFT", 4, 0)

    -- Member name
    local nameText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    nameText:SetText(accountID)
    nameText:SetPoint("LEFT", row, "LEFT", 22, 0)

    -- Level
    local levelText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    levelText:SetText("Lvl " .. tostring(member.highestLevel or 0))
    levelText:SetPoint("LEFT", row, "LEFT", 150, 0)
    if member.isAlive then
        levelText:SetTextColor(BP_Color(BLOODPACT_COLORS.ALIVE))
    else
        levelText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))
    end

    -- Death count
    local deathText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    deathText:SetText("(" .. tostring(member.deathCount or 0) .. " deaths)")
    deathText:SetPoint("LEFT", row, "LEFT", 210, 0)
    deathText:SetTextColor(0.8, 0.3, 0.3, 1)

    -- Status label
    local statusLabel = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    if member.isAlive then
        statusLabel:SetText("ALIVE")
        statusLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.ALIVE))
    else
        statusLabel:SetText("DECEASED")
        statusLabel:SetTextColor(1.0, 0.2, 0.2, 1)
    end
    statusLabel:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    return row
end

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_PactDashboard:Initialize()
    local content = BloodPact_MainFrame:GetContentFrame()
    if content then
        self:Create(content)
    end
end
