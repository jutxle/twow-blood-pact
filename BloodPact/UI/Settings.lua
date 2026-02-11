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

    -- Scrollable content area
    local scrollFrame = CreateFrame("ScrollFrame", "BPSettingsScroll", panel)
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local delta = arg1
        local current = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(math.max(0, current - delta * 24))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    scrollChild:SetWidth(parent:GetWidth() - 8)
    scrollFrame:SetScrollChild(scrollChild)

    panel.scrollFrame = scrollFrame
    panel.scrollChild = scrollChild

    local yOffset = -8

    -- Account Information section
    yOffset = self:CreateSection(scrollChild, "Account Information", yOffset, function(section)
        panel.displayNameLine = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.displayNameLine:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -20)
        panel.displayNameLine:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        panel.setNameHint = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.setNameHint:SetPoint("TOPLEFT", panel.displayNameLine, "BOTTOMLEFT", 0, -2)
        panel.setNameHint:SetText("Change: /bp setname <name>")
        panel.setNameHint:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

        panel.createdLine = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.createdLine:SetPoint("TOPLEFT", panel.setNameHint, "BOTTOMLEFT", 0, -4)
        panel.createdLine:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

        -- Main character selector
        local mainLabel = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        mainLabel:SetPoint("TOPLEFT", panel.createdLine, "BOTTOMLEFT", 0, -8)
        mainLabel:SetText("Main hardcore character:")
        mainLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        panel.mainCharText = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.mainCharText:SetPoint("LEFT", mainLabel, "RIGHT", 6, 0)
        panel.mainCharText:SetTextColor(1, 1, 1, 1)

        local setMainBtn = BP_CreateButton(section, "Set Current", 70, 18)
        setMainBtn:SetPoint("LEFT", panel.mainCharText, "RIGHT", 8, 0)
        setMainBtn:SetScript("OnClick", function()
            local charName = UnitName("player")
            if charName and BloodPact_RosterDataManager then
                BloodPact_RosterDataManager:SetMainCharacter(charName)
                BloodPact_Settings:Refresh()
                BloodPact_Logger:Print("Main character set to: " .. charName)
                if BloodPact_PactManager:IsInPact() then
                    BloodPact_SyncEngine:BroadcastRosterSnapshot()
                end
            end
        end)

        local clearMainBtn = BP_CreateButton(section, "Clear", 50, 18)
        clearMainBtn:SetPoint("LEFT", setMainBtn, "RIGHT", 4, 0)
        clearMainBtn:SetScript("OnClick", function()
            if BloodPact_RosterDataManager then
                BloodPact_RosterDataManager:SetMainCharacter(nil)
                BloodPact_Settings:Refresh()
                BloodPact_Logger:Print("Main character cleared. Current character will be used.")
            end
        end)

        -- Hardcore manual flag checkbox area
        local hcLabel = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        hcLabel:SetPoint("TOPLEFT", mainLabel, "BOTTOMLEFT", 0, -8)
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

        section:SetHeight(150)
    end)

    -- Blood Pact Membership section
    yOffset = self:CreateSection(scrollChild, "Blood Pact Membership", yOffset, function(section)
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
            BloodPact_Logger:Print("To join a pact, type: /bloodpact join <code>")
        end)

        local orLabel = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        orLabel:SetText("- OR -")
        orLabel:SetPoint("TOPLEFT", panel.joinCodeLabel, "BOTTOMLEFT", 0, -30)
        orLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

        local createBtn = BP_CreateButton(section, "Create New Pact", 120, 22)
        createBtn:SetPoint("TOPLEFT", orLabel, "BOTTOMLEFT", 0, -8)
        createBtn:SetScript("OnClick", function()
            BloodPact_Logger:Print("To create a pact, type: /bloodpact create <name>")
        end)

        section:SetHeight(130)
    end)

    -- UI Preferences section
    yOffset = self:CreateSection(scrollChild, "UI Preferences", yOffset, function(section)
        local alphaLabel = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        alphaLabel:SetText("Window transparency:")
        alphaLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -20)
        alphaLabel:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

        panel.alphaValueText = BP_CreateFontString(section, BP_FONT_SIZE_SMALL)
        panel.alphaValueText:SetPoint("LEFT", alphaLabel, "RIGHT", 8, 0)
        panel.alphaValueText:SetTextColor(1, 1, 1, 1)

        local minusBtn = BP_CreateButton(section, "-", 28, 20)
        minusBtn:SetPoint("LEFT", panel.alphaValueText, "RIGHT", 8, 0)
        minusBtn:SetScript("OnClick", function()
            self:AdjustTransparency(-0.05)
        end)

        local plusBtn = BP_CreateButton(section, "+", 28, 20)
        plusBtn:SetPoint("LEFT", minusBtn, "RIGHT", 4, 0)
        plusBtn:SetScript("OnClick", function()
            self:AdjustTransparency(0.05)
        end)

        section:SetHeight(55)
    end)

    -- Data Management section
    yOffset = self:CreateSection(scrollChild, "Data Management", yOffset, function(section)
        local wipeBtn = BP_CreateButton(section, "Wipe All Data", 110, 22)
        wipeBtn:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -20)
        wipeBtn:SetScript("OnClick", function()
            BloodPact_Logger:Print("Type /bloodpact wipe confirm to permanently delete all death data.")
        end)

        section:SetHeight(50)
    end)

    -- Set scroll child height to fit all content
    local totalHeight = 8 - yOffset
    scrollChild:SetHeight(math.max(1, totalHeight))

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
-- Transparency
-- ============================================================

function BloodPact_Settings:AdjustTransparency(delta)
    if not BloodPactAccountDB or not BloodPactAccountDB.config then return end
    local alpha = BloodPactAccountDB.config.windowAlpha or 1.0
    alpha = alpha + delta
    if alpha < 0.5 then alpha = 0.5 end
    if alpha > 1.0 then alpha = 1.0 end
    BloodPactAccountDB.config.windowAlpha = alpha
    BloodPact_MainFrame:ApplyTransparency()
    self:Refresh()
end

-- ============================================================
-- Refresh
-- ============================================================

function BloodPact_Settings:Refresh()
    if not panel then return end

    -- Account info
    local displayName = BloodPact_AccountIdentity:GetDisplayName() or "Unknown"
    if panel.displayNameLine then
        panel.displayNameLine:SetText("Display Name: " .. displayName)
    end

    -- Main character display
    if panel.mainCharText and BloodPact_RosterDataManager then
        local main = BloodPact_RosterDataManager:GetMainCharacter()
        local current = UnitName("player")
        if main then
            panel.mainCharText:SetText(main .. (current == main and " (current)" or ""))
        else
            panel.mainCharText:SetText((current or "?") .. " (current)")
        end
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

    -- Transparency display
    if panel.alphaValueText then
        local alpha = (BloodPactAccountDB and BloodPactAccountDB.config and BloodPactAccountDB.config.windowAlpha) or 1.0
        panel.alphaValueText:SetText(string.format("%d%%", math.floor(alpha * 100 + 0.5)))
    end

    -- Pact status
    if panel.pactStatusText then
        if BloodPact_PactManager:IsInPact() then
            local pact = BloodPactAccountDB.pact
            panel.pactStatusText:SetText("In pact: " .. BP_SanitizeText(pact.pactName or "?") .. "  [" .. (pact.joinCode or "?") .. "]")
            panel.pactStatusText:SetTextColor(1.0, 0.4, 0.0, 1)
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
