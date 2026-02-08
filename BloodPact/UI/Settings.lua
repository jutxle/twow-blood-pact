-- Blood Pact - Settings Panel
-- Account info, pact creation/joining, data management, and UI preferences

BloodPact_Settings = {}

local panel = nil

-- ============================================================
-- Construction
-- ============================================================

function BloodPact_Settings:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panel:Hide()

    local yOffset = -8

    -- Account Information section
    yOffset = self:CreateSection(panel, "Account Information", yOffset, function(section)
        panel.accountIDLine = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.accountIDLine:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -20)
        panel.accountIDLine:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        panel.createdLine = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.createdLine:SetPoint("TOPLEFT", panel.accountIDLine, "BOTTOMLEFT", 0, -4)
        panel.createdLine:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

        -- Hardcore manual flag checkbox area
        local hcLabel = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        hcLabel:SetPoint("TOPLEFT", panel.createdLine, "BOTTOMLEFT", 0, -8)
        hcLabel:SetText("[ ] I am playing hardcore (manual flag)")
        hcLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))
        panel.hcFlagLabel = hcLabel

        local hcBtn = BP_CreateButton(section, "Toggle", 60, 18)
        hcBtn:SetPoint("LEFT", hcLabel, "RIGHT", 4, 0)
        hcBtn:SetScript("OnClick", function()
            if BloodPactAccountDB and BloodPactAccountDB.config then
                local current = BloodPactAccountDB.config.manualHardcoreFlag
                BloodPactAccountDB.config.manualHardcoreFlag = not current
                BloodPact_Settings:Refresh()
                BloodPact_Logger:Print("Hardcore flag: " .. (BloodPactAccountDB.config.manualHardcoreFlag and "ENABLED" or "DISABLED"))
            end
        end)

        section:SetHeight(90)
    end)

    -- Blood Pact Membership section
    yOffset = self:CreateSection(panel, "Blood Pact Membership", yOffset, function(section)
        panel.pactStatusText = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.pactStatusText:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -20)
        panel.pactStatusText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        -- Join code input area
        panel.joinCodeLabel = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.joinCodeLabel:SetPoint("TOPLEFT", panel.pactStatusText, "BOTTOMLEFT", 0, -8)
        panel.joinCodeLabel:SetText("Join Code:")
        panel.joinCodeLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        panel.joinCodeInput = CreateFrame("Frame", nil, section)
        panel.joinCodeInput:SetWidth(140)
        panel.joinCodeInput:SetHeight(20)
        panel.joinCodeInput:SetPoint("LEFT", panel.joinCodeLabel, "RIGHT", 6, 0)
        BP_ApplyPanelBackdrop(panel.joinCodeInput)

        -- Simple text display (WoW 1.12 EditBox is complex; use a button prompt)
        panel.joinCodeValue = BP_CreateFontString(panel.joinCodeInput, BP_FONT_SIZE_SMALL)
        panel.joinCodeValue:SetText("Enter code...")
        panel.joinCodeValue:SetPoint("LEFT", panel.joinCodeInput, "LEFT", 4, 0)
        panel.joinCodeValue:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

        local joinBtn = BP_CreateButton(section, "Join Pact", 70, 20)
        joinBtn:SetPoint("LEFT", panel.joinCodeInput, "RIGHT", 6, 0)
        joinBtn:SetScript("OnClick", function()
            -- Prompt via chat input since we can't easily do inline EditBox
            BloodPact_Logger:Print("To join a pact, type: |cFFFFAA00/bloodpact join <code>|r")
        end)

        local orLabel = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        orLabel:SetText("- OR -")
        orLabel:SetPoint("TOPLEFT", panel.joinCodeLabel, "BOTTOMLEFT", 0, -30)
        orLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

        local createBtn = BP_CreateButton(section, "Create New Pact", 120, 22)
        createBtn:SetPoint("TOPLEFT", orLabel, "BOTTOMLEFT", 0, -8)
        createBtn:SetScript("OnClick", function()
            BloodPact_Logger:Print("To create a pact, type: |cFFFFAA00/bloodpact create <name>|r")
        end)

        section:SetHeight(130)
    end)

    -- Data Management section
    yOffset = self:CreateSection(panel, "Data Management", yOffset, function(section)
        local wipeBtn = BP_CreateButton(section, "Wipe All Data", 110, 22)
        wipeBtn:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -20)
        wipeBtn:SetScript("OnClick", function()
            BloodPact_Logger:Print("Type |cFFFF4444/bloodpact wipe confirm|r to permanently delete all death data.")
        end)

        section:SetHeight(50)
    end)

    -- Register as tab 3 (Settings)
    BloodPact_MainFrame:RegisterTabPanel(3, panel)

    panel.Refresh = function() BloodPact_Settings:Refresh() end
    BloodPact_Settings.panel = panel
end

-- Helper: create a titled section frame and call contentFunc to populate it
function BloodPact_Settings:CreateSection(parent, title, yOffset, contentFunc)
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    section:SetPoint("LEFT", parent, "LEFT", 8, 0)
    section:SetWidth(parent:GetWidth() - 16)
    section:SetHeight(60)  -- default; contentFunc may resize
    BP_ApplyPanelBackdrop(section)

    local titleText = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
    titleText:SetText(title)
    titleText:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -6)
    titleText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    local divider = BP_CreateDivider(section, 400)
    divider:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)

    if contentFunc then contentFunc(section) end

    return yOffset - section:GetHeight() - 6
end

-- ============================================================
-- Refresh
-- ============================================================

function BloodPact_Settings:Refresh()
    if not panel then return end

    -- Account info
    local accountID = BloodPact_AccountIdentity:GetAccountID() or "Unknown"
    if panel.accountIDLine then
        panel.accountIDLine:SetText("Account ID: " .. accountID)
    end
    if panel.createdLine and BloodPactAccountDB and BloodPactAccountDB.accountCreatedTimestamp then
        panel.createdLine:SetText("Created: " .. date("%Y-%m-%d %H:%M:%S", BloodPactAccountDB.accountCreatedTimestamp))
    end

    -- Hardcore flag display
    if panel.hcFlagLabel then
        local flagEnabled = BloodPactAccountDB and BloodPactAccountDB.config and BloodPactAccountDB.config.manualHardcoreFlag
        if flagEnabled then
            panel.hcFlagLabel:SetText("[X] I am playing hardcore (manual flag)")
            panel.hcFlagLabel:SetTextColor(0.4, 1.0, 0.4, 1)
        else
            panel.hcFlagLabel:SetText("[ ] I am playing hardcore (manual flag)")
            panel.hcFlagLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))
        end
    end

    -- Pact status
    if panel.pactStatusText then
        if BloodPact_PactManager:IsInPact() then
            local pact = BloodPactAccountDB.pact
            panel.pactStatusText:SetText("In pact: |cFFFF6600" .. (pact.pactName or "?") .. "|r  [" .. (pact.joinCode or "?") .. "]")
        else
            panel.pactStatusText:SetText("Not in a pact.")
        end
    end
end

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_Settings:Initialize()
    local content = BloodPact_MainFrame:GetContentFrame()
    if content then
        self:Create(content)
    end
end
