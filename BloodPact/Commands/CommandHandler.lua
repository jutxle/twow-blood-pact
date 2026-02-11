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
        -- Strip everything except letters and numbers (handles dashes, spaces, etc.)
        code = string.upper(string.gsub(code, "[^A-Za-z0-9]", ""))
        self:HandleJoin(code)
    elseif input == "wipe" then
        BloodPact_Logger:Print("Type /bloodpact wipe confirm to permanently delete all death data.")
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
    elseif input == "reset" then
        BloodPact_MainFrame:ResetPosition()
        BloodPact_MainFrame:Show()
    elseif input == "simjoin" or string.sub(input, 1, 8) == "simjoin " then
        local accountName = string.sub(rawInput, 9)
        self:HandleSimJoin(accountName)
    elseif input == "simdeath" or string.sub(input, 1, 9) == "simdeath " then
        local rest = string.sub(rawInput, 10)
        self:HandleSimDeath(rest)
    elseif input == "simremove" or string.sub(input, 1, 10) == "simremove " then
        local accountName = string.sub(rawInput, 11)
        self:HandleSimRemove(accountName)
    else
        BloodPact_Logger:Print("Unknown command. Type /bloodpact help for a list of commands.")
    end
end

function BloodPact_CommandHandler:HandleCreate(name)
    if not name or string.len(name) == 0 then
        BloodPact_Logger:Print("Usage: /bloodpact create <pact name>")
        return
    end

    if string.len(name) > 32 then
        BloodPact_Logger:Print("Pact name too long. Maximum 32 characters.")
        return
    end

    if BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You are already in a Blood Pact. Leave your current pact first.")
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
        BloodPact_Logger:Print("Invalid join code format. Codes are 8 characters (letters and numbers). Example: A7K9M2X5")
        return
    end

    if BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You are already in a Blood Pact. Leave your current pact first.")
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

-- ============================================================
-- Simulation Commands (for testing without multiple accounts)
-- ============================================================

-- /bp simjoin <accountName> - Simulate a player joining your pact
function BloodPact_CommandHandler:HandleSimJoin(accountName)
    if not accountName or string.len(accountName) == 0 then
        BloodPact_Logger:Print("Usage: /bp simjoin <accountName>")
        return
    end
    if not BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You must be in a pact first. Use /bp create <name>")
        return
    end

    local members = BloodPactAccountDB.pact.members
    if members[accountName] then
        BloodPact_Logger:Print("'" .. accountName .. "' is already in the pact.")
        return
    end

    -- Add the fake member
    members[accountName] = {
        accountID       = accountName,
        highestLevel    = math.random(1, 40),
        deathCount      = 0,
        isAlive         = true,
        joinedTimestamp = time()
    }

    BloodPact_Logger:Print("[SIM] '" .. accountName .. "' joined the pact (Lvl " .. tostring(members[accountName].highestLevel) .. ").")

    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end

-- /bp simdeath <accountName> [charName] [level] [zone] [killer]
-- All args after accountName are optional with sensible defaults.
-- Routes through the full network pipeline: serialize → inject → deserialize → process.
function BloodPact_CommandHandler:HandleSimDeath(rest)
    if not rest or string.len(rest) == 0 then
        BloodPact_Logger:Print("Usage: /bp simdeath <accountName> [charName] [level] [zone] [killer]")
        return
    end
    if not BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You must be in a pact first.")
        return
    end

    -- Parse space-separated args
    local args = {}
    for word in string.gfind(rest, "%S+") do
        table.insert(args, word)
    end

    local accountName = args[1]
    if not accountName then
        BloodPact_Logger:Print("Usage: /bp simdeath <accountName> [charName] [level] [zone] [killer]")
        return
    end

    -- Auto-join the member if they don't exist yet
    local members = BloodPactAccountDB.pact.members
    if not members[accountName] then
        members[accountName] = {
            accountID       = accountName,
            highestLevel    = 0,
            deathCount      = 0,
            isAlive         = true,
            joinedTimestamp = time()
        }
        BloodPact_Logger:Print("[SIM] Auto-added '" .. accountName .. "' to pact.")
    end

    local charName = args[2] or (accountName .. "Char")
    local level    = tonumber(args[3]) or math.random(5, 35)
    local zone     = args[4] or "Duskwood"
    local killer   = args[5] or "Stitches"

    -- Build fake death record
    local deathRecord = {
        characterName = charName,
        level         = level,
        timestamp     = time() - math.random(0, 300),
        serverTime    = date("%Y-%m-%d %H:%M:%S"),
        zoneName      = zone,
        subZoneName   = "",
        killerName    = killer,
        killerLevel   = math.random(math.max(1, level - 2), level + 5),
        killerType    = "NPC",
        copperAmount  = math.random(100, 50000),
        race          = "Human",
        class         = "Warrior",
        totalXP       = (BLOODPACT_XP_PER_LEVEL[level] or 0) + math.random(0, 2000),
        equippedItems = {},
        version       = BLOODPACT_SCHEMA_VERSION,
        accountID     = accountName,
    }

    -- Serialize as if sending over the network, then inject into receive pipeline
    local pactCode = BloodPact_PactManager:GetPactCode()
    local serialized = BloodPact_Serialization:SerializeDeathAnnounce(accountName, pactCode, deathRecord)

    BloodPact_Logger:Print("[SIM] Serialized DA message (" .. string.len(serialized) .. " bytes), injecting into receive pipeline...")
    BloodPact_SyncEngine:InjectMessage(serialized, accountName)

    BloodPact_Logger:Print("[SIM] " .. accountName .. "'s " .. charName ..
        " (Lvl " .. tostring(level) .. ") died to " .. killer .. " in " .. zone)

    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end

-- /bp simremove <accountName> - Remove a simulated member from the pact
function BloodPact_CommandHandler:HandleSimRemove(accountName)
    if not accountName or string.len(accountName) == 0 then
        BloodPact_Logger:Print("Usage: /bp simremove <accountName>")
        return
    end
    if not BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You must be in a pact first.")
        return
    end

    local selfID = BloodPact_AccountIdentity:GetAccountID()
    if accountName == selfID then
        BloodPact_Logger:Print("Cannot remove yourself from the pact.")
        return
    end

    local members = BloodPactAccountDB.pact.members
    if not members[accountName] then
        BloodPact_Logger:Print("'" .. accountName .. "' is not in the pact.")
        return
    end

    members[accountName] = nil

    -- Also clean up their synced deaths
    if BloodPactAccountDB.pact.syncedDeaths then
        BloodPactAccountDB.pact.syncedDeaths[accountName] = nil
    end

    BloodPact_Logger:Print("[SIM] Removed '" .. accountName .. "' from the pact.")

    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end
