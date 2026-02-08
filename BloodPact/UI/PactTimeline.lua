-- Blood Pact - Pact Timeline
-- Unified scrollable timeline of all pact member deaths

BloodPact_PactTimeline = {}

local panel = nil
local eventRows = {}
local currentMemberFilter = nil  -- nil = all members

-- ============================================================
-- Construction
-- ============================================================

function BloodPact_PactTimeline:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panel:Hide()

    self:CreateFilterBar()
    self:CreateScrollArea()
    self:CreateBackButton()

    BloodPact_PactTimeline.panel = panel
end

function BloodPact_PactTimeline:CreateFilterBar()
    local filterBar = CreateFrame("Frame", nil, panel)
    filterBar:SetHeight(26)
    filterBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    BP_ApplyBackdrop(filterBar)
    filterBar:SetBackdropColor(0.12, 0.12, 0.12, 1)

    local filterLabel = BP_CreateFontString(filterBar, BP_FONT_SIZE_SMALL)
    filterLabel:SetText("Member Filter:")
    filterLabel:SetPoint("LEFT", filterBar, "LEFT", 8, 0)
    filterLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    panel.filterText = BP_CreateFontString(filterBar, BP_FONT_SIZE_SMALL)
    panel.filterText:SetText("All Members")
    panel.filterText:SetPoint("LEFT", filterLabel, "RIGHT", 4, 0)

    local cycleBtn = BP_CreateButton(filterBar, "Cycle Filter", 80, 18)
    cycleBtn:SetPoint("LEFT", panel.filterText, "RIGHT", 8, 0)
    cycleBtn:SetScript("OnClick", function()
        BloodPact_PactTimeline:CycleFilter()
    end)

    panel.filterBar = filterBar
end

function BloodPact_PactTimeline:CreateScrollArea()
    local scrollFrame = CreateFrame("ScrollFrame", "BPPactTimelineScroll", panel)
    scrollFrame:SetPoint("TOPLEFT", panel.filterBar, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 30)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local delta = arg1
        local current = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(math.max(0, current - delta * 30))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(1)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    panel.scrollFrame = scrollFrame
    panel.scrollChild = scrollChild
end

function BloodPact_PactTimeline:CreateBackButton()
    local backBtn = BP_CreateButton(panel, "Back to Pact", 100, 22)
    backBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 4)
    backBtn:SetScript("OnClick", function()
        BloodPact_PactTimeline:Hide()
        BloodPact_PactDashboard:Refresh()
        if BloodPact_PactDashboard.panel then
            BloodPact_PactDashboard.panel:Show()
        end
    end)
end

-- ============================================================
-- Filter Cycling
-- ============================================================

function BloodPact_PactTimeline:CycleFilter()
    if not BloodPact_PactManager:IsInPact() then return end
    local members = BloodPactAccountDB.pact.members
    if not members then return end

    -- Build sorted list of member IDs
    local ids = {}
    for id in pairs(members) do
        table.insert(ids, id)
    end
    table.sort(ids)

    if table.getn(ids) == 0 then return end

    if currentMemberFilter == nil then
        currentMemberFilter = ids[1]
    else
        local found = false
        for i, id in ipairs(ids) do
            if id == currentMemberFilter then
                if i < table.getn(ids) then
                    currentMemberFilter = ids[i + 1]
                else
                    currentMemberFilter = nil
                end
                found = true
                break
            end
        end
        if not found then currentMemberFilter = nil end
    end

    self:Refresh()
end

-- ============================================================
-- Show / Hide
-- ============================================================

function BloodPact_PactTimeline:Show()
    if not panel then return end
    if BloodPact_PactDashboard.panel then
        BloodPact_PactDashboard.panel:Hide()
    end
    panel:Show()
    self:Refresh()
end

function BloodPact_PactTimeline:Hide()
    if panel then panel:Hide() end
end

-- ============================================================
-- Refresh
-- ============================================================

function BloodPact_PactTimeline:Refresh()
    if not panel then return end

    if panel.filterText then
        panel.filterText:SetText(currentMemberFilter or "All Members")
    end

    -- Clear existing rows
    for _, row in ipairs(eventRows) do
        row:Hide()
        row:SetParent(nil)
    end
    eventRows = {}

    -- Get all pact deaths
    local allDeaths = BloodPact_DeathDataManager:GetAllPactDeaths()

    -- Apply member filter
    local filtered = {}
    for _, death in ipairs(allDeaths) do
        if currentMemberFilter == nil or death.ownerAccountID == currentMemberFilter then
            table.insert(filtered, death)
        end
    end

    local yOffset = 0
    for _, death in ipairs(filtered) do
        local row = self:CreateDeathRow(panel.scrollChild, death, yOffset)
        table.insert(eventRows, row)
        yOffset = yOffset - row:GetHeight() - 4
    end

    panel.scrollChild:SetHeight(math.max(1, -yOffset))
    panel.scrollFrame:SetVerticalScroll(0)
end

-- ============================================================
-- Death Row
-- ============================================================

function BloodPact_PactTimeline:CreateDeathRow(parent, death, yOffset)
    local rowH = 72
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowH)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset)

    -- Per-player color from hash
    local r, g, b = self:GetOwnerColor(death.ownerAccountID)
    row:SetBackdrop(BP_BACKDROP)
    row:SetBackdropColor(r * 0.2, g * 0.2 + 0.05, b * 0.2, 0.85)
    row:SetBackdropBorderColor(r * 0.5, g * 0.5, b * 0.5, 1)

    -- Timestamp
    local ts = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    ts:SetText(death.serverTime or date("%Y-%m-%d %H:%M:%S", death.timestamp))
    ts:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
    ts:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

    -- Death label
    local deathLabel = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    deathLabel:SetText("● DEATH")
    deathLabel:SetPoint("LEFT", ts, "RIGHT", 8, 0)
    deathLabel:SetTextColor(1.0, 0.2, 0.2, 1)

    -- Owner attribution
    local ownerText = BP_CreateFontString(row, BP_FONT_SIZE_MEDIUM)
    local ownerDisplay = (death.ownerAccountID or "?") .. "'s " .. (death.characterName or "?")
    ownerText:SetText(ownerDisplay .. " (Lvl " .. tostring(death.level or 0) .. ")")
    ownerText:SetPoint("TOPLEFT", ts, "BOTTOMLEFT", 0, -4)
    ownerText:SetTextColor(r, g, b, 1)

    -- Killer
    local killer = death.killerName or "Unknown"
    if death.killerLevel and death.killerLevel > 0 then
        killer = killer .. " (" .. tostring(death.killerLevel) .. ")"
    end
    local killerText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    killerText:SetText("killed by " .. killer)
    killerText:SetPoint("TOPLEFT", ownerText, "BOTTOMLEFT", 0, -2)
    killerText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    -- Location
    local locStr = (death.zoneName or "Unknown")
    if death.subZoneName and string.len(death.subZoneName) > 0 then
        locStr = locStr .. " (" .. death.subZoneName .. ")"
    end
    local locText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    locText:SetText("Location: " .. locStr)
    locText:SetPoint("TOPLEFT", killerText, "BOTTOMLEFT", 0, -2)
    locText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

    return row
end

-- Get a consistent color for a player based on their account ID
function BloodPact_PactTimeline:GetOwnerColor(accountID)
    if not accountID then return 0.8, 0.8, 0.8 end

    local hash = 0
    for i = 1, string.len(accountID) do
        hash = hash + string.byte(accountID, i)
    end

    local idx = math.mod(hash, table.getn(BLOODPACT_PLAYER_COLORS)) + 1
    local c = BLOODPACT_PLAYER_COLORS[idx]
    return c[1], c[2], c[3]
end

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_PactTimeline:Initialize()
    local content = BloodPact_MainFrame:GetContentFrame()
    if content then
        self:Create(content)
    end
end
