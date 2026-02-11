-- Blood Pact - Dungeon Detail Overlay
-- Shows dungeon completion progress for a pact member
-- Opened by clicking a roster card in PactDashboard

BloodPact_DungeonDetailOverlay = {}

local panel = nil
local dungeonRows = {}
local currentAccountID = nil

-- ============================================================
-- Construction
-- ============================================================

function BloodPact_DungeonDetailOverlay:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panel:Hide()

    self:CreateHeader()
    self:CreateScrollArea()
    self:CreateBackButton()

    BloodPact_DungeonDetailOverlay.panel = panel
end

function BloodPact_DungeonDetailOverlay:CreateHeader()
    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(44)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -4)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -4)
    BP_ApplyPanelBackdrop(header)

    panel.headerNameText = BP_CreateFontString(header, BP_FONT_SIZE_MEDIUM)
    panel.headerNameText:SetPoint("TOPLEFT", header, "TOPLEFT", 8, -6)
    panel.headerNameText:SetTextColor(1.0, 0.84, 0.0, 1)

    panel.headerCountText = BP_CreateFontString(header, BP_FONT_SIZE_SMALL)
    panel.headerCountText:SetPoint("TOPLEFT", panel.headerNameText, "BOTTOMLEFT", 0, -4)
    panel.headerCountText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    panel.header = header
end

function BloodPact_DungeonDetailOverlay:CreateScrollArea()
    local scrollFrame = CreateFrame("ScrollFrame", "BPDungeonDetailScroll", panel)
    scrollFrame:SetPoint("TOPLEFT", panel.header, "BOTTOMLEFT", -8, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 30)
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

function BloodPact_DungeonDetailOverlay:CreateBackButton()
    local backBtn = BP_CreateButton(panel, "Back to Pact", 100, 22)
    backBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 4)
    backBtn:SetScript("OnClick", function()
        BloodPact_DungeonDetailOverlay:Hide()
    end)
end

-- ============================================================
-- Show / Hide
-- ============================================================

function BloodPact_DungeonDetailOverlay:ShowForMember(accountID)
    if not panel then return end
    currentAccountID = accountID

    -- Hide the pact dashboard
    if BloodPact_PactDashboard.panel then
        BloodPact_PactDashboard.panel:Hide()
    end
    -- Hide pact timeline if open
    if BloodPact_PactTimeline and BloodPact_PactTimeline.Hide then BloodPact_PactTimeline:Hide() end

    panel:Show()
    self:Refresh()
end

function BloodPact_DungeonDetailOverlay:Hide()
    if panel then panel:Hide() end
    -- Re-show pact dashboard
    if BloodPact_PactDashboard.panel then
        BloodPact_PactDashboard.panel:Show()
        BloodPact_PactDashboard:Refresh()
    end
end

-- ============================================================
-- Refresh / Render
-- ============================================================

function BloodPact_DungeonDetailOverlay:Refresh()
    if not panel or not currentAccountID then return end

    -- Clear existing rows
    for _, row in ipairs(dungeonRows) do
        row:Hide()
        row:SetParent(nil)
    end
    dungeonRows = {}

    -- Get display name for header
    local displayName = self:GetMemberDisplayName(currentAccountID)

    -- Get completions
    local completions = BloodPact_DungeonDataManager:GetMemberCompletions(currentAccountID)
    local totalCompleted = 0
    for _ in pairs(completions) do
        totalCompleted = totalCompleted + 1
    end
    local totalDungeons = BLOODPACT_DUNGEON_COUNT or 0

    -- Update header
    if panel.headerNameText then
        panel.headerNameText:SetText(BP_SanitizeText(displayName) .. "'s Dungeon Progress")
    end
    if panel.headerCountText then
        local pct = totalDungeons > 0 and math.floor((totalCompleted / totalDungeons) * 100) or 0
        panel.headerCountText:SetText(tostring(totalCompleted) .. " / " .. tostring(totalDungeons) .. " completed (" .. tostring(pct) .. "%)")

        -- Color based on completion percentage
        if pct >= 50 then
            panel.headerCountText:SetTextColor(0.4, 1.0, 0.4, 1)
        elseif pct >= 25 then
            panel.headerCountText:SetTextColor(1.0, 0.84, 0.0, 1)
        else
            panel.headerCountText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))
        end
    end

    -- Render grouped dungeon list
    local yOffset = 0

    for _, group in ipairs(BLOODPACT_DUNGEON_GROUPS) do
        local groupDungeons = self:GetDungeonsForGroup(group.key)
        if table.getn(groupDungeons) > 0 then
            local groupCompleted = 0
            for _, dg in ipairs(groupDungeons) do
                if completions[dg.id] then
                    groupCompleted = groupCompleted + 1
                end
            end

            -- Group header
            yOffset = self:RenderGroupHeader(yOffset, group.label, groupCompleted, table.getn(groupDungeons))

            -- Individual dungeon rows
            for _, dg in ipairs(groupDungeons) do
                local ts = completions[dg.id]
                yOffset = self:RenderDungeonRow(yOffset, dg, ts)
            end

            -- Spacing after group
            yOffset = yOffset - 6
        end
    end

    panel.scrollChild:SetHeight(math.max(1, -yOffset))
    panel.scrollFrame:SetVerticalScroll(0)
end

-- ============================================================
-- Rendering Helpers
-- ============================================================

function BloodPact_DungeonDetailOverlay:RenderGroupHeader(yOffset, label, completed, total)
    local row = CreateFrame("Frame", nil, panel.scrollChild)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 8, yOffset)
    row:SetPoint("TOPRIGHT", panel.scrollChild, "TOPRIGHT", -8, yOffset)

    local divLeft = row:CreateTexture(nil, "ARTWORK")
    divLeft:SetHeight(1)
    divLeft:SetWidth(40)
    divLeft:SetPoint("LEFT", row, "LEFT", 0, 0)
    divLeft:SetTexture(0.4, 0.4, 0.4, 0.8)

    local headerText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    headerText:SetText(label .. " [" .. tostring(completed) .. "/" .. tostring(total) .. "]")
    headerText:SetPoint("LEFT", divLeft, "RIGHT", 6, 0)
    headerText:SetTextColor(1.0, 0.84, 0.0, 1)

    local divRight = row:CreateTexture(nil, "ARTWORK")
    divRight:SetHeight(1)
    divRight:SetWidth(40)
    divRight:SetPoint("LEFT", headerText, "RIGHT", 6, 0)
    divRight:SetTexture(0.4, 0.4, 0.4, 0.8)

    table.insert(dungeonRows, row)
    return yOffset - 22
end

function BloodPact_DungeonDetailOverlay:RenderDungeonRow(yOffset, dungeon, completionTimestamp)
    local row = CreateFrame("Frame", nil, panel.scrollChild)
    row:SetHeight(18)
    row:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 12, yOffset)
    row:SetPoint("TOPRIGHT", panel.scrollChild, "TOPRIGHT", -12, yOffset)

    local isComplete = completionTimestamp ~= nil

    -- Status icon
    local statusText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    if isComplete then
        statusText:SetText("v")
        statusText:SetTextColor(BP_Color(BLOODPACT_COLORS.ALIVE))
    else
        statusText:SetText("x")
        statusText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))
    end
    statusText:SetPoint("LEFT", row, "LEFT", 4, 0)

    -- Dungeon name
    local nameText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    nameText:SetText(dungeon.name)
    nameText:SetPoint("LEFT", statusText, "RIGHT", 6, 0)
    if isComplete then
        nameText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_PRIMARY))
    else
        nameText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))
    end

    -- Level range
    local levelText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    levelText:SetText("(" .. tostring(dungeon.levelMin) .. "-" .. tostring(dungeon.levelMax) .. ")")
    levelText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    levelText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

    -- Completion date (right-aligned)
    local dateText = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    if isComplete then
        dateText:SetText(date("%Y-%m-%d", completionTimestamp))
    else
        dateText:SetText("--")
    end
    dateText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    dateText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

    table.insert(dungeonRows, row)
    return yOffset - 18
end

-- ============================================================
-- Data Helpers
-- ============================================================

-- Get dungeons belonging to a specific group
function BloodPact_DungeonDetailOverlay:GetDungeonsForGroup(groupKey)
    local result = {}
    if not BLOODPACT_DUNGEON_DATABASE then return result end
    for _, dungeon in ipairs(BLOODPACT_DUNGEON_DATABASE) do
        if dungeon.group == groupKey then
            table.insert(result, dungeon)
        end
    end
    return result
end

-- Get the display name for a pact member (for UI headers)
function BloodPact_DungeonDetailOverlay:GetMemberDisplayName(accountID)
    if BloodPact_AccountIdentity and BloodPact_AccountIdentity.GetDisplayNameFor then
        return BloodPact_AccountIdentity:GetDisplayNameFor(accountID)
    end
    return accountID or "?"
end

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_DungeonDetailOverlay:Initialize()
    local content = BloodPact_MainFrame:GetContentFrame()
    if content then
        self:Create(content)
    end
end
