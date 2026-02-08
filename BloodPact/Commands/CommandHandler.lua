-- Blood Pact - Command Handler
-- Registers and routes /bloodpact slash commands

BloodPact_CommandHandler = {}

-- Register slash command
SLASH_BLOODPACT1 = "/bloodpact"
SLASH_BLOODPACT2 = "/bp"

SlashCmdList["BLOODPACT"] = function(input)
    BloodPact_CommandHandler:HandleCommand(input)
end

function BloodPact_CommandHandler:HandleCommand(input)
    if not input then input = "" end
    local rawInput = string.gsub(input, "^%s*(.-)%s*$", "%1")  -- trim whitespace (preserve case)
    input = string.lower(rawInput)

    if input == "" or input == "show" then
        BloodPact_MainFrame:Show()
    elseif input == "hide" then
        BloodPact_MainFrame:Hide()
    elseif input == "toggle" then
        BloodPact_MainFrame:Toggle()
    elseif string.sub(input, 1, 7) == "create " then
        local name = string.sub(rawInput, 8)  -- original case
        self:HandleCreate(name)
    elseif string.sub(input, 1, 5) == "join " then
        local code = string.sub(input, 6)
        code = string.upper(string.gsub(code, "%s", ""))
        self:HandleJoin(code)
    elseif input == "wipe" then
        BloodPact_Logger:Print("Type |cFFFF4444/bloodpact wipe confirm|r to permanently delete all death data.")
        BloodPact_Logger:Print("Your account ID and pact membership will be preserved.")
    elseif input == "wipe confirm" then
        self:HandleWipe()
    elseif string.sub(input, 1, 6) == "export" then
        BloodPact_Logger:Print("Export functionality not yet implemented.")
    elseif input == "status" then
        self:ShowStatus()
    elseif input == "help" then
        self:ShowHelp()
    elseif input == "debug" then
        BloodPact_Logger:SetLevel(BloodPact_Logger.LEVEL.INFO)
        BloodPact_Logger:Print("Debug logging enabled.")
    elseif input == "nodebug" then
        BloodPact_Logger:SetLevel(BloodPact_Logger.LEVEL.WARNING)
        BloodPact_Logger:Print("Debug logging disabled.")
    else
        BloodPact_Logger:Print("Unknown command. Type |cFFFFAA00/bloodpact help|r for a list of commands.")
    end
end

function BloodPact_CommandHandler:HandleCreate(name)
    if not name or string.len(name) == 0 then
        BloodPact_Logger:Print("Usage: /bloodpact create <pact name>")
        return
    end

    if string.len(name) > 32 then
        BloodPact_Logger:Print("|cFFFF4444Pact name too long.|r Maximum 32 characters.")
        return
    end

    if BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("|cFFFF4444You are already in a Blood Pact.|r Leave your current pact first.")
        BloodPact_Logger:Print("(Note: Leaving pacts not yet implemented in v1.0)")
        return
    end

    BloodPact_PactManager:CreatePact(name)
end

function BloodPact_CommandHandler:HandleJoin(code)
    if not code or string.len(code) == 0 then
        BloodPact_Logger:Print("Usage: /bloodpact join <8-character code>")
        return
    end

    if not BloodPact_JoinCodeGenerator:ValidateCodeFormat(code) then
        BloodPact_Logger:Print("|cFFFF4444Invalid join code format.|r Codes are 8 characters (letters and numbers). Example: A7K9M2X5")
        return
    end

    if BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("|cFFFF4444You are already in a Blood Pact.|r Leave your current pact first.")
        BloodPact_Logger:Print("(Note: Leaving pacts not yet implemented in v1.0)")
        return
    end

    BloodPact_PactManager:RequestJoin(code)
end

function BloodPact_CommandHandler:HandleWipe()
    BloodPact_DeathDataManager:WipeAllDeaths()
    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end

function BloodPact_CommandHandler:ShowStatus()
    BloodPact_Logger:Print("=== Blood Pact Status ===")
    local accountID = BloodPact_AccountIdentity:GetAccountID() or "None"
    BloodPact_Logger:Print("Account ID: " .. accountID)
    local deaths = BloodPact_DeathDataManager:GetTotalDeaths()
    BloodPact_Logger:Print("Total deaths tracked: " .. tostring(deaths))
    if BloodPact_PactManager:IsInPact() then
        local pact = BloodPactAccountDB.pact
        BloodPact_Logger:Print("Pact: " .. (pact.pactName or "?") .. " [" .. (pact.joinCode or "?") .. "]")
        local memberCount = 0
        if pact.members then
            for _ in pairs(pact.members) do memberCount = memberCount + 1 end
        end
        BloodPact_Logger:Print("Members: " .. tostring(memberCount))
    else
        BloodPact_Logger:Print("Not in a pact.")
    end
    BloodPact_Logger:Print("UI panels: " .. (BloodPact_PersonalDashboard.panel and "OK" or "MISSING"))
end

function BloodPact_CommandHandler:ShowHelp()
    BloodPact_Logger:Print("Blood Pact v" .. BLOODPACT_VERSION .. " - Hardcore Death Tracker")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact          - Open the Blood Pact window")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact show     - Open the Blood Pact window")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact hide     - Close the Blood Pact window")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact toggle   - Toggle window visibility")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact create <name> - Create a new Blood Pact")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact join <code> - Join a Blood Pact using a join code")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact wipe     - Wipe all death data (requires confirmation)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact help     - Show this help message")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp                 - Shortcut for /bloodpact")
end
