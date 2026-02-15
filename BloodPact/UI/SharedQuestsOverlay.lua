-- Blood Pact - Shared Quests Overlay
-- Displays quests shared between the local player and pact members
-- Opened via the "Shared Quests" button on PactDashboard

BloodPact_SharedQuestsOverlay = {}

local panel = nil
local questRows = {}

-- ============================================================
-- Construction
-- ============================================================

function BloodPact_SharedQuestsOverlay:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panel:Hide()

    self:CreateHeader()
    self:CreateScrollArea()
    self:CreateBackButton()

    BloodPact_SharedQuestsOverlay.panel = panel
end

function BloodPact_SharedQuestsOverlay:CreateHeader()
    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(44)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -4)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -4)
    BP_ApplyPanelBackdrop(header)

    panel.headerTitleText = BP_CreateFontString(header, BP_FONT_SIZE_MEDIUM)
    panel.headerTitleText:SetPoint("TOPLEFT", header, "TOPLEFT", 8, -6)
    panel.headerTitleText:SetTextColor(1.0, 0.84, 0.0, 1)
    panel.headerTitleText:SetText("Shared Quests")

    panel.headerCountText = BP_CreateFontString(header, BP_FONT_SIZE_SMALL)
    panel.headerCountText:SetPoint("TOPLEFT", panel.headerTitleText, "BOTTOMLEFT", 0, -4)
    panel.headerCountText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    panel.header = header
end

function BloodPact_SharedQuestsOverlay:CreateScrollArea()
    local scrollFrame = CreateFrame("ScrollFrame", "BPSharedQuestsScroll", panel)
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

function BloodPact_SharedQuestsOverlay:CreateBackButton()
    local backBtn = BP_CreateButton(panel, "Back to Pact", 100, 22)
    backBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 4)
    backBtn:SetScript("OnClick", function()
        BloodPact_SharedQuestsOverlay:Hide()
    end)
end

-- ============================================================
-- Show / Hide
-- ============================================================

function BloodPact_SharedQuestsOverlay:Show()
    if not panel then return end

    -- Hide the pact dashboard
    if BloodPact_PactDashboard and BloodPact_PactDashboard.panel then
        BloodPact_PactDashboard.panel:Hide()
    end
    -- Hide pact timeline if open
    if BloodPact_PactTimeline and BloodPact_PactTimeline.Hide then
        BloodPact_PactTimeline:Hide()
    end
    -- Hide dungeon overlay if open
    if BloodPact_DungeonDetailOverlay and BloodPact_DungeonDetailOverlay.panel then
        BloodPact_DungeonDetailOverlay.panel:Hide()
    end

    panel:Show()
    self:Refresh()
end

function BloodPact_SharedQuestsOverlay:Hide()
    if panel then panel:Hide() end
    -- Re-show pact dashboard
    if BloodPact_PactDashboard and BloodPact_PactDashboard.panel then
        BloodPact_PactDashboard.panel:Show()
        BloodPact_PactDashboard:Refresh()
    end
end

-- ============================================================
-- Refresh / Render
-- ============================================================

function BloodPact_SharedQuestsOverlay:Refresh()
    if not panel then return end

    -- Clear existing rows
    for _, row in ipairs(questRows) do
        row:Hide()
        row:SetParent(nil)
    end
    questRows = {}

    local sharedQuests = {}
    if BloodPact_QuestDataManager then
        sharedQuests = BloodPact_QuestDataManager:GetSharedQuests()
    end
    local count = table.getn(sharedQuests)

    -- Update header
    if panel.headerCountText then
        if count > 0 then
            panel.headerCountText:SetText(tostring(count) .. " quest(s) shared with pact members")
            panel.headerCountText:SetTextColor(0.4, 1.0, 0.4, 1)
        else
            panel.headerCountText:SetText("No shared quests found")
            panel.headerCountText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))
        end
    end

    -- Render quest rows
    local yOffset = 0

    if count == 0 then
        yOffset = self:RenderEmptyState(yOffset)
    else
        for _, entry in ipairs(sharedQuests) do
            yOffset = self:RenderQuestEntry(yOffset, entry.questTitle, entry.members)
        end
    end

    panel.scrollChild:SetHeight(math.max(1, -yOffset))
    panel.scrollFrame:SetVerticalScroll(0)
end

-- ============================================================
-- Rendering Helpers
-- ============================================================

function BloodPact_SharedQuestsOverlay:RenderEmptyState(yOffset)
    local row = CreateFrame("Frame", nil, panel.scrollChild)
    row:SetHeight(40)
    row:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 8, yOffset - 20)
    row:SetPoint("TOPRIGHT", panel.scrollChild, "TOPRIGHT", -8, yOffset - 20)

    local msg = BP_CreateFontString(row, BP_FONT_SIZE_SMALL)
    msg:SetText("No quests in common with pact members.\nQuest logs update automatically when members are online.")
    msg:SetPoint("CENTER", row, "CENTER", 0, 0)
    msg:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

    table.insert(questRows, row)
    return yOffset - 60
end

function BloodPact_SharedQuestsOverlay:RenderQuestEntry(yOffset, questTitle, memberAccountIDs)
    -- Quest title row
    local titleRow = CreateFrame("Frame", nil, panel.scrollChild)
    titleRow:SetHeight(18)
    titleRow:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 8, yOffset)
    titleRow:SetPoint("TOPRIGHT", panel.scrollChild, "TOPRIGHT", -8, yOffset)

    local titleText = BP_CreateFontString(titleRow, BP_FONT_SIZE_SMALL)
    titleText:SetText(BP_SanitizeText(questTitle))
    titleText:SetPoint("LEFT", titleRow, "LEFT", 4, 0)
    titleText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_PRIMARY))

    table.insert(questRows, titleRow)
    yOffset = yOffset - 18

    -- Member names row (indented, secondary color)
    local names = {}
    for _, accountID in ipairs(memberAccountIDs) do
        local displayName = "?"
        if BloodPact_AccountIdentity and BloodPact_AccountIdentity.GetDisplayNameFor then
            displayName = BloodPact_AccountIdentity:GetDisplayNameFor(accountID)
        end
        table.insert(names, BP_SanitizeText(displayName))
    end
    local memberStr = "  Shared with: " .. table.concat(names, ", ")

    local memberRow = CreateFrame("Frame", nil, panel.scrollChild)
    memberRow:SetHeight(14)
    memberRow:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 8, yOffset)
    memberRow:SetPoint("TOPRIGHT", panel.scrollChild, "TOPRIGHT", -8, yOffset)

    local memberText = BP_CreateFontString(memberRow, BP_FONT_SIZE_SMALL)
    memberText:SetText(memberStr)
    memberText:SetPoint("LEFT", memberRow, "LEFT", 12, 0)
    memberText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    table.insert(questRows, memberRow)
    yOffset = yOffset - 16

    return yOffset
end

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_SharedQuestsOverlay:Initialize()
    local content = BloodPact_MainFrame:GetContentFrame()
    if content then
        self:Create(content)
    end
end
