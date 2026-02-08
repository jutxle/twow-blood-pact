-- Blood Pact - Main Frame
-- Primary UI window with title bar, tab system, and status bar

BloodPact_MainFrame = {}

local frame = nil
local TAB_PERSONAL  = 1
local TAB_PACT      = 2
local TAB_SETTINGS  = 3
local activeTab     = TAB_PERSONAL

-- Tab content panels (populated by their respective modules)
local tabPanels = {}

-- ============================================================
-- Frame Construction
-- ============================================================

function BloodPact_MainFrame:Create()
    if frame then return end

    -- Main window
    frame = CreateFrame("Frame", "BloodPactMainFrame", UIParent)
    frame:SetWidth(BLOODPACT_WINDOW_WIDTH)
    frame:SetHeight(BLOODPACT_WINDOW_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("DIALOG")
    BP_ApplyBackdrop(frame, true)

    -- Restore saved position
    if BloodPactAccountDB and BloodPactAccountDB.config then
        local x = BloodPactAccountDB.config.windowX
        local y = BloodPactAccountDB.config.windowY
        if x and y then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        end
    end

    -- Save position on drag
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if BloodPactAccountDB and BloodPactAccountDB.config then
            local x, y = frame:GetLeft(), frame:GetTop()
            BloodPactAccountDB.config.windowX = x
            BloodPactAccountDB.config.windowY = y - UIParent:GetHeight()
        end
    end)

    -- Build sub-sections
    self:CreateTitleBar()
    self:CreateTabBar()
    self:CreateContentArea()
    self:CreateStatusBar()

    -- Start hidden
    frame:Hide()

    BloodPact_MainFrame.frame = frame
end

function BloodPact_MainFrame:CreateTitleBar()
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(24)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    BP_ApplyBackdrop(titleBar, true)
    titleBar:SetBackdropColor(0.08, 0.08, 0.08, 1)

    -- Make window draggable via title bar
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if BloodPactAccountDB and BloodPactAccountDB.config then
            local x, y = frame:GetLeft(), frame:GetTop()
            BloodPactAccountDB.config.windowX = x
            BloodPactAccountDB.config.windowY = y - UIParent:GetHeight()
        end
    end)

    -- Title text
    local title = BP_CreateFontString(titleBar, BP_FONT_SIZE_LARGE)
    title:SetText("|cFFFF6600Blood Pact|r")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    local closeTex = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTex:SetFont(BP_FONT, BP_FONT_SIZE_MEDIUM, "OUTLINE")
    closeTex:SetText("X")
    closeTex:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeTex:SetTextColor(0.8, 0.3, 0.3, 1)
    closeBtn:SetScript("OnClick", function() BloodPact_MainFrame:Hide() end)

    frame.titleBar = titleBar
end

function BloodPact_MainFrame:CreateTabBar()
    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetHeight(26)
    tabBar:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", frame.titleBar, "BOTTOMRIGHT", 0, 0)
    BP_ApplyBackdrop(tabBar)
    tabBar:SetBackdropColor(0.12, 0.12, 0.12, 1)

    local tabNames = {"Personal", "Pact", "Settings"}
    local tabWidth = 100
    frame.tabs = {}

    for i = 1, 3 do
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetWidth(tabWidth)
        tab:SetHeight(24)
        tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", (i - 1) * tabWidth + 4, 1)
        BP_ApplyBackdrop(tab)

        local label = BP_CreateFontString(tab, BP_FONT_SIZE_SMALL)
        label:SetText(tabNames[i])
        label:SetPoint("CENTER", tab, "CENTER", 0, 0)
        tab.label = label

        local tabIndex = i
        tab:SetScript("OnClick", function()
            BloodPact_MainFrame:SwitchTab(tabIndex)
        end)
        tab:SetScript("OnEnter", function()
            if activeTab ~= tabIndex then
                tab:SetBackdropColor(0.22, 0.22, 0.22, 1)
            end
        end)
        tab:SetScript("OnLeave", function()
            if activeTab ~= tabIndex then
                tab:SetBackdropColor(0.15, 0.15, 0.15, 0.95)
            end
        end)

        frame.tabs[i] = tab
    end

    frame.tabBar = tabBar
    self:UpdateTabHighlight()
end

function BloodPact_MainFrame:CreateContentArea()
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame.tabBar, "BOTTOMLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 26)  -- leave room for status bar
    frame.content = content
end

function BloodPact_MainFrame:CreateStatusBar()
    local statusBar = CreateFrame("Frame", nil, frame)
    statusBar:SetHeight(26)
    statusBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    BP_ApplyBackdrop(statusBar, true)
    statusBar:SetBackdropColor(0.08, 0.08, 0.08, 1)

    frame.accountIDText = BP_CreateFontString(statusBar, BP_FONT_SIZE_SMALL)
    frame.accountIDText:SetPoint("LEFT", statusBar, "LEFT", 8, 0)
    frame.accountIDText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))

    local versionText = BP_CreateFontString(statusBar, BP_FONT_SIZE_SMALL)
    versionText:SetText("Blood Pact v" .. BLOODPACT_VERSION)
    versionText:SetPoint("RIGHT", statusBar, "RIGHT", -8, 0)
    versionText:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))

    frame.statusBar = statusBar
end

-- ============================================================
-- Tab Management
-- ============================================================

function BloodPact_MainFrame:RegisterTabPanel(tabIndex, panel)
    tabPanels[tabIndex] = panel
end

function BloodPact_MainFrame:SwitchTab(tabIndex)
    -- Disable Pact tab if not in pact
    if tabIndex == TAB_PACT and not BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You are not in a Blood Pact. Join or create one in the Settings tab.")
        return
    end

    activeTab = tabIndex
    self:UpdateTabHighlight()

    -- Show/hide panels
    for i, panel in pairs(tabPanels) do
        if panel and panel.Hide then
            if i == tabIndex then
                panel:Show()
                if panel.Refresh then panel:Refresh() end
            else
                panel:Hide()
            end
        end
    end
end

function BloodPact_MainFrame:UpdateTabHighlight()
    if not frame or not frame.tabs then return end
    for i, tab in ipairs(frame.tabs) do
        if i == activeTab then
            tab:SetBackdropColor(0.28, 0.28, 0.28, 1)
            tab:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            tab.label:SetTextColor(1, 1, 1, 1)
        else
            -- Gray out Pact tab if not in pact
            if i == TAB_PACT and not BloodPact_PactManager:IsInPact() then
                tab:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
                tab.label:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_DISABLED))
            else
                tab:SetBackdropColor(0.15, 0.15, 0.15, 0.95)
                tab.label:SetTextColor(BP_Color(BLOODPACT_COLORS.TEXT_SECONDARY))
            end
            tab:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        end
    end
end

-- ============================================================
-- Public Interface
-- ============================================================

function BloodPact_MainFrame:Show()
    if not frame then self:Create() end

    -- Update account ID in status bar
    local accountID = BloodPact_AccountIdentity:GetAccountID()
    if frame.accountIDText then
        frame.accountIDText:SetText("Account: " .. (accountID or "Unknown"))
    end

    frame:Show()
    self:SwitchTab(activeTab)
end

function BloodPact_MainFrame:Hide()
    if frame then frame:Hide() end
end

function BloodPact_MainFrame:Toggle()
    if not frame or not frame:IsVisible() then
        self:Show()
    else
        self:Hide()
    end
end

function BloodPact_MainFrame:IsVisible()
    return frame and frame:IsVisible()
end

function BloodPact_MainFrame:Refresh()
    if not frame or not frame:IsVisible() then return end
    local panel = tabPanels[activeTab]
    if panel and panel.Refresh then panel:Refresh() end
    self:UpdateTabHighlight()
end

function BloodPact_MainFrame:GetContentFrame()
    return frame and frame.content
end
