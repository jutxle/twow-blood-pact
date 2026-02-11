-- Blood Pact - Pact Dashboard
-- Displays pact-level statistics and member roster with character cards

BloodPact_PactDashboard = {}

local panel = nil
local rosterCards = {}

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
    header:SetText("Pact Roster (Main Characters)")
    header:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, -6)
    header:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    local divider = BP_CreateDivider(listFrame, 500)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)

    local scrollFrame = CreateFrame("ScrollFrame", "BPPactRosterScroll", listFrame)
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
        if BloodPact_PactTimeline and BloodPact_PactTimeline.Show then
            BloodPact_PactTimeline:Show()
        else
            BloodPact_Logger:Print("Pact Timeline not available. Try /reload - if it persists, the PactTimeline module failed to load.")
        end
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

    -- Rebuild roster cards
    self:RefreshRosterCards()
end

function BloodPact_PactDashboard:RefreshRosterCards()
    for _, card in ipairs(rosterCards) do
        card:Hide()
        card:SetParent(nil)
    end
    rosterCards = {}

    if not panel.memberScrollChild then return end
    if not BloodPactAccountDB.pact or not BloodPactAccountDB.pact.members then return end

    local pact = BloodPactAccountDB.pact
    local rosterSnapshots = pact.rosterSnapshots or {}
    local selfID = BloodPact_AccountIdentity:GetAccountID()

    -- Card dimensions: 2 columns (height accommodates display name + char/class + level + professions + talents)
    local cardW = 275
    local cardH = 122
    local padX = 4
    local padY = 6
    local cols = 2

    local idx = 0
    for accountID, member in pairs(pact.members) do
        local snapshot = rosterSnapshots[accountID]
        -- Use our own live snapshot when this is us
        if accountID == selfID and BloodPact_RosterDataManager then
            snapshot = BloodPact_RosterDataManager:GetCurrentSnapshot()
        end
        local col = math.mod(idx, cols)
        local row = math.floor(idx / cols)
        local card = self:CreateRosterCard(panel.memberScrollChild, accountID, member, snapshot, col, row, cardW, cardH, padX, padY)
        table.insert(rosterCards, card)
        idx = idx + 1
    end

    local totalRows = math.ceil(idx / cols)
    panel.memberScrollChild:SetHeight(math.max(1, totalRows * (cardH + padY)))
end

function BloodPact_PactDashboard:CreateRosterCard(parent, accountID, member, snapshot, col, row, cardW, cardH, padX, padY)
    local card = CreateFrame("Button", nil, parent)
    card:SetWidth(cardW)
    card:SetHeight(cardH)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT",
        col * (cardW + padX),
        -(row * (cardH + padY)))

    BP_ApplyPanelBackdrop(card)

    -- Display name (user-facing) and character name (from roster snapshot)
    local displayName = BloodPact_AccountIdentity and BloodPact_AccountIdentity:GetDisplayNameFor(accountID) or accountID
    local charName = (snapshot and snapshot.characterName and snapshot.characterName ~= "") and snapshot.characterName or accountID
    local class = (snapshot and snapshot.class) or ""
    local level = (snapshot and snapshot.level) or member.highestLevel or 0
    local copper = (snapshot and snapshot.copper) or 0
    local prof1 = (snapshot and snapshot.profession1) or ""
    local prof1Lvl = (snapshot and snapshot.profession1Level) or 0
    local prof2 = (snapshot and snapshot.profession2) or ""
    local prof2Lvl = (snapshot and snapshot.profession2Level) or 0
    local talentTabs = (snapshot and snapshot.talentTabs) or {}

    -- Row 1: Status icon + Account Display Name
    local statusIcon = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    if member.isAlive then
        statusIcon:SetText("✓")
        statusIcon:SetTextColor(BP_Color(BLOODPACT_COLORS.ALIVE))
    else
        statusIcon:SetText("☠")
        statusIcon:SetTextColor(BP_Color(BLOODPACT_COLORS.DECEASED))
    end
    statusIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)

    local displayNameText = BP_CreateFontString(card, BP_FONT_SIZE_MEDIUM)
    displayNameText:SetText(BP_SanitizeText(displayName))
    displayNameText:SetPoint("LEFT", statusIcon, "RIGHT", 4, 0)
    displayNameText:SetTextColor(1, 1, 1, 1)

    -- Row 2: Character Name | Class
    local classColor = {1, 1, 1}
    if BLOODPACT_CLASS_COLORS and class and class ~= "" then
        local c = BLOODPACT_CLASS_COLORS[string.upper(class)]
        if c then classColor = c end
    end
    local charClassText = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    local charClassStr = BP_SanitizeText(charName)
    if class ~= "" then charClassStr = charClassStr .. " | " .. class end
    charClassText:SetText(charClassStr)
    charClassText:SetPoint("TOPLEFT", statusIcon, "BOTTOMLEFT", 0, -4)
    charClassText:SetTextColor(classColor[1], classColor[2], classColor[3], 1)

    -- Row 3: Level | Currency
    local levelText = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    levelText:SetText("Lvl " .. tostring(level))
    levelText:SetPoint("TOPLEFT", charClassText, "BOTTOMLEFT", 0, -4)
    levelText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_PRIMARY))

    local goldText = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    goldText:SetText(" | " .. BloodPact_DeathDataManager:FormatCopper(copper))
    goldText:SetPoint("LEFT", levelText, "RIGHT", 2, 0)
    goldText:SetTextColor(1.0, 0.84, 0.0, 1)
    -- Row 4: Professions (show name even if level is 0)
    local profStr = ""
    if prof1 ~= "" then
        profStr = prof1 .. " " .. tostring(prof1Lvl)
    end
    if prof2 ~= "" then
        if profStr ~= "" then profStr = profStr .. " | " end
        profStr = profStr .. prof2 .. " " .. tostring(prof2Lvl)
    end
    if profStr == "" then profStr = "—" end

    local profText = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    profText:SetText(profStr)
    profText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -4)
    profText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    -- Row 5: Talents (all 3 trees with points spent: "Affliction 5 | Demonology 3 | Destruction 0")
    local talentParts = {}
    for _, tab in ipairs(talentTabs) do
        local name = tab.name or ""
        local pts = tab.pointsSpent or 0
        table.insert(talentParts, name .. " " .. tostring(pts))
    end
    local talentStr = table.concat(talentParts, " | ")
    if talentStr == "" then talentStr = "—" end

    local talentText = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    talentText:SetText(talentStr)
    talentText:SetPoint("TOPLEFT", profText, "BOTTOMLEFT", 0, -4)
    talentText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    -- Death count
    local deathCount = BloodPact_DeathDataManager:GetDeathCountForMember(accountID)
    local deathText = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    deathText:SetText(tostring(deathCount) .. " death(s)")
    deathText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -6, 6)
    deathText:SetTextColor(0.8, 0.3, 0.3, 1)

    -- "Click for dungeons" hint
    local hintText = BP_CreateFontString(card, BP_FONT_SIZE_SMALL)
    hintText:SetText("Click for dungeons")
    hintText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 6, 6)
    hintText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

    -- Click handler to open dungeon detail overlay
    local clickAccountID = accountID
    card:SetScript("OnClick", function()
        if BloodPact_DungeonDetailOverlay and BloodPact_DungeonDetailOverlay.ShowForMember then
            BloodPact_DungeonDetailOverlay:ShowForMember(clickAccountID)
        end
    end)

    -- Hover highlight
    card:SetScript("OnEnter", function()
        card:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)
    card:SetScript("OnLeave", function()
        card:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
    end)

    return card
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
