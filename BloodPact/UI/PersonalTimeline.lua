-- Blood Pact - Personal Timeline
-- Scrollable list of death events and level milestones for the player's own characters

BloodPact_PersonalTimeline = {}

local panel = nil
local eventRows = {}
local currentFilter = nil  -- nil = all characters; else { charName, characterInstanceID }
local currentSort = "newest"
local expandedDeaths = {}   -- keys = "charName_instanceID_timestamp", tracks which details are open

-- ============================================================
-- Construction
-- ============================================================

function BloodPact_PersonalTimeline:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameLevel(10)
    panel:Hide()

    self:CreateFilterBar()
    self:CreateScrollArea()
    self:CreateBackButton()

    BloodPact_PersonalTimeline.panel = panel
end

function BloodPact_PersonalTimeline:CreateFilterBar()
    local filterBar = CreateFrame("Frame", nil, panel)
    filterBar:SetHeight(26)
    filterBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    BP_ApplyBackdrop(filterBar)
    filterBar:SetBackdropColor(0.12, 0.12, 0.12, 1)

    local filterLabel = BP_CreateFontString(filterBar, BP_FONT_SIZE_SMALL)
    filterLabel:SetText("Character Filter:")
    filterLabel:SetPoint("LEFT", filterBar, "LEFT", 8, 0)
    filterLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    -- Simple text display showing current filter (dropdown not straightforward in 1.12)
    panel.filterText = BP_CreateFontString(filterBar, BP_FONT_SIZE_SMALL)
    panel.filterText:SetText("All Characters")
    panel.filterText:SetPoint("LEFT", filterLabel, "RIGHT", 4, 0)

    -- Cycle filter button
    local cycleBtn = BP_CreateButton(filterBar, "Cycle Filter", 80, 18)
    cycleBtn:SetPoint("LEFT", panel.filterText, "RIGHT", 8, 0)
    cycleBtn:SetScript("OnClick", function()
        BloodPact_PersonalTimeline:CycleFilter()
    end)

    panel.filterBar = filterBar
end

function BloodPact_PersonalTimeline:CreateScrollArea()
    local scrollFrame = CreateFrame("ScrollFrame", "BPPersonalTimelineScroll", panel)
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

function BloodPact_PersonalTimeline:CreateBackButton()
    local backBtn = BP_CreateButton(panel, "Back to Dashboard", 120, 22)
    backBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 4)
    backBtn:SetScript("OnClick", function()
        BloodPact_PersonalTimeline:Hide()
        BloodPact_PersonalDashboard:Refresh()
        if BloodPact_PersonalDashboard.panel then
            BloodPact_PersonalDashboard.panel:Show()
        end
    end)
end

-- ============================================================
-- Filter Cycling
-- ============================================================

function BloodPact_PersonalTimeline:CycleFilter()
    local summaries = BloodPact_DeathDataManager:GetCharacterSummaries()
    if table.getn(summaries) == 0 then return end

    if currentFilter == nil then
        currentFilter = {
            charName = summaries[1].characterName,
            characterInstanceID = summaries[1].characterInstanceID
        }
    else
        -- Find next character instance
        local found = false
        for i, s in ipairs(summaries) do
            if s.characterName == currentFilter.charName and
               (s.characterInstanceID or "") == (currentFilter.characterInstanceID or "") then
                if i < table.getn(summaries) then
                    currentFilter = {
                        charName = summaries[i + 1].characterName,
                        characterInstanceID = summaries[i + 1].characterInstanceID
                    }
                else
                    currentFilter = nil  -- wrap back to "all"
                end
                found = true
                break
            end
        end
        if not found then currentFilter = nil end
    end

    self:Refresh()
end

-- ============================================================
-- Show/Hide/Filter
-- ============================================================

function BloodPact_PersonalTimeline:Show()
    if not panel then return end
    -- Hide dashboard, show timeline
    if BloodPact_PersonalDashboard.panel then
        BloodPact_PersonalDashboard.panel:Hide()
    end
    panel:Show()
    self:Refresh()
end

function BloodPact_PersonalTimeline:ShowForCharacter(charName, characterInstanceID)
    currentFilter = charName and {
        charName = charName,
        characterInstanceID = characterInstanceID
    } or nil
    self:Show()
end

function BloodPact_PersonalTimeline:Hide()
    if panel then panel:Hide() end
end

-- ============================================================
-- Refresh / Render
-- ============================================================

function BloodPact_PersonalTimeline:Refresh()
    if not panel then return end

    -- Update filter label
    if panel.filterText then
        if currentFilter then
            local summaries = BloodPact_DeathDataManager:GetCharacterSummaries()
            local nameCounts = {}
            for _, s in ipairs(summaries) do
                local n = s.characterName or "?"
                nameCounts[n] = (nameCounts[n] or 0) + 1
                if s.characterName == currentFilter.charName and
                   (s.characterInstanceID or "") == (currentFilter.characterInstanceID or "") then
                    local disp = (nameCounts[n] > 1) and (n .. " #" .. tostring(nameCounts[n])) or n
                    panel.filterText:SetText(disp)
                    break
                end
            end
        else
            panel.filterText:SetText("All Characters")
        end
    end

    -- Clear existing rows
    for _, row in ipairs(eventRows) do
        row:Hide()
        row:SetParent(nil)
    end
    eventRows = {}

    -- Get deaths
    local deaths
    if currentFilter then
        deaths = BloodPact_DeathDataManager:GetDeaths(currentFilter.charName, currentFilter.characterInstanceID)
    else
        deaths = BloodPact_DeathDataManager:GetDeaths(nil)
    end

    local yOffset = 0
    for _, death in ipairs(deaths) do
        local row = self:CreateDeathRow(panel.scrollChild, death, yOffset)
        table.insert(eventRows, row)
        yOffset = yOffset - row:GetHeight() - 4
    end

    panel.scrollChild:SetHeight(math.max(1, -yOffset))
    panel.scrollFrame:SetVerticalScroll(0)
end

-- ============================================================
-- Death Row Rendering
-- ============================================================

function BloodPact_PersonalTimeline:CreateDeathRow(parent, death, yOffset)
    local rowH = 80
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowH)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset)
    row:SetBackdrop(BP_BACKDROP)
    row:SetBackdropColor(0.22, 0.10, 0.10, 0.85)
    row:SetBackdropBorderColor(0.4, 0.15, 0.15, 1)

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

    -- Main death info (flavorful phrasing with killer/ability)
    local deathMsg = BloodPact_DeathDataManager:FormatDeathMessage(death)
    local mainText = BP_CreateFontString(row, BP_FONT_SIZE_MEDIUM)
    mainText:SetText(BP_SanitizeText(deathMsg))
    mainText:SetPoint("TOPLEFT", ts, "BOTTOMLEFT", 0, -4)
    mainText:SetTextColor(1, 1, 1, 1)

    -- Location
    local locStr = BP_SanitizeText(death.zoneName) or "Unknown"
    if death.subZoneName and string.len(death.subZoneName) > 0 then
        locStr = locStr .. " (" .. BP_SanitizeText(death.subZoneName) .. ")"
    end
    local locText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    locText:SetText("Location: " .. locStr)
    locText:SetPoint("TOPLEFT", mainText, "BOTTOMLEFT", 0, -2)
    locText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    -- Gold/items lost
    local goldStr = BloodPact_DeathDataManager:FormatCopper(death.copperAmount)
    local itemCount = table.getn(death.equippedItems or {})
    local lostText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    lostText:SetText("Lost: " .. goldStr .. (itemCount > 0 and (", " .. tostring(itemCount) .. " rare+ items") or ""))
    lostText:SetPoint("TOPLEFT", locText, "BOTTOMLEFT", 0, -2)
    lostText:SetTextColor(1.0, 0.84, 0.0, 1)

    -- View/hide details button
    local deathKey = tostring(death.characterName or "?") .. "_" .. tostring(death.characterInstanceID or "?") .. "_" .. tostring(death.timestamp or 0)
    local isExpanded = expandedDeaths[deathKey]
    local detailsBtn = BP_CreateButton(row, isExpanded and "Close" or "Details", 60, 16)
    detailsBtn:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)

    local detailFrame = self:CreateDetailsExpansion(row, death)
    if isExpanded then
        detailFrame:Show()
        row:SetHeight(rowH + detailFrame:GetHeight() + 4)
    else
        detailFrame:Hide()
    end

    detailsBtn:SetScript("OnClick", function()
        expandedDeaths[deathKey] = not expandedDeaths[deathKey]
        -- Re-layout all rows
        BloodPact_PersonalTimeline:Refresh()
    end)

    return row
end

function BloodPact_PersonalTimeline:CreateDetailsExpansion(parent, death)
    local detailH = 20 + table.getn(death.equippedItems or {}) * 16 + 4
    if detailH < 20 then detailH = 20 end

    local detail = CreateFrame("Frame", nil, parent)
    detail:SetHeight(detailH)
    detail:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -76)
    detail:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -76)

    if table.getn(death.equippedItems or {}) == 0 then
        local noItems = BP_CreateFontString(detail, BP_FONT_SIZE_SMALL)
        noItems:SetText("No rare or better items equipped.")
        noItems:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
        noItems:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))
    else
        local header = BP_CreateFontString(detail, BP_FONT_SIZE_SMALL)
        header:SetText("Equipped Items:")
        header:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
        header:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        for i, item in ipairs(death.equippedItems) do
            local itemLine = BP_CreateFontString(detail, BP_FONT_SIZE_SMALL)
            itemLine:SetText("  - " .. BP_SanitizeText(item.itemName or "?") .. " (" .. BP_SanitizeText(item.slot or "?") .. ")")
            itemLine:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -(i * 16))
            local r, g, b = BP_GetQualityColor(item.itemQuality)
            itemLine:SetTextColor(r, g, b, 1)
        end
    end

    return detail
end

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_PersonalTimeline:Initialize()
    local content = BloodPact_MainFrame:GetContentFrame()
    if content then
        self:Create(content)
    end
end
