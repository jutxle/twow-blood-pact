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
        BloodPact_Logger:Print("Your display name and pact membership will be preserved.")
    elseif input == "wipe confirm" then
        self:HandleWipe()
    elseif string.sub(input, 1, 6) == "export" then
        BloodPact_Logger:Print("Export functionality not yet implemented.")
    elseif input == "setmain" then
        self:HandleSetMain()
    elseif input == "status" then
        self:ShowStatus()
    elseif input == "sync" then
        self:HandleSync()
    elseif string.sub(input, 1, 8) == "setname " then
        local name = string.sub(rawInput, 9)
        self:HandleSetName(name)
    elseif input == "help" then
        self:ShowHelp()
    elseif input == "debug" then
        BloodPact_Logger:SetLevel(BloodPact_Logger.LEVEL.DEBUG)
        BloodPact_Logger:Print("Verbose debug logging enabled.")
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
    elseif string.sub(input, 1, 12) == "deletedeath " then
        local rest = string.gsub(string.sub(rawInput, 13), "^%s*(.-)%s*$", "%1")
        self:HandleDeleteDeath(rest)
    elseif string.sub(input, 1, 5) == "kick " then
        local accountName = string.gsub(string.sub(rawInput, 6), "^%s*(.-)%s*$", "%1")
        self:HandleKick(accountName)
    elseif input == "dungeondebug" then
        self:HandleDungeonDebug()
    elseif input == "simdungeon" or string.sub(input, 1, 11) == "simdungeon " then
        local rest = string.sub(rawInput, 12)
        self:HandleSimDungeon(rest)
    elseif input == "errors" then
        self:ShowErrors()
    elseif input == "clearerrors" then
        BloodPact_Debug:ClearErrorLog()
        BloodPact_Logger:Print("Error log cleared.")
    elseif input == "trace" then
        local current = BloodPact_Debug:IsTraceEnabled()
        BloodPact_Debug:SetTraceEnabled(not current)
        BloodPact_Logger:Print("Message tracing: " .. (not current and "ENABLED" or "DISABLED"))
    elseif input == "dump" then
        BloodPact_Debug:DumpState()
    elseif string.sub(input, 1, 8) == "profile " or input == "profile" then
        local sub = ""
        if string.len(input) > 8 then
            sub = string.gsub(string.sub(input, 9), "^%s*(.-)%s*$", "%1")
        end
        self:HandleProfile(sub)
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

function BloodPact_CommandHandler:HandleSetMain()
    local charName = UnitName("player")
    if not charName then
        BloodPact_Logger:Print("Could not get character name.")
        return
    end
    if BloodPact_RosterDataManager then
        BloodPact_RosterDataManager:SetMainCharacter(charName)
        BloodPact_Logger:Print("Main character set to: " .. charName)
        if BloodPact_PactManager:IsInPact() then
            BloodPact_SyncEngine:BroadcastRosterSnapshot()
        end
        if BloodPact_Settings and BloodPact_Settings.Refresh then
            BloodPact_Settings:Refresh()
        end
    end
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

function BloodPact_CommandHandler:HandleSetName(name)
    if not name or string.len(string.gsub(name, "^%s*(.-)%s*$", "%1")) == 0 then
        BloodPact_Logger:Print("Usage: /bp setname <display name>")
        BloodPact_Logger:Print("  Sets your display name (shown to pact members). Max 32 characters.")
        return
    end
    if BloodPact_AccountIdentity:SetDisplayName(name) then
        local displayName = BloodPact_AccountIdentity:GetDisplayName()
        BloodPact_Logger:Print("Display name set to: " .. displayName)
        if BloodPact_PactManager:IsInPact() then
            BloodPact_SyncEngine:BroadcastRosterSnapshot(true)
            BloodPact_Logger:Print("Pact members will see your new name.")
        end
        if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
            BloodPact_MainFrame:Refresh()
        end
        if BloodPact_Settings and BloodPact_Settings.Refresh then
            BloodPact_Settings:Refresh()
        end
    else
        BloodPact_Logger:Print("Could not set display name.")
    end
end

function BloodPact_CommandHandler:HandleSync()
    if not BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You are not in a Blood Pact. Nothing to sync.")
        return
    end
    BloodPact_Logger:Print("Requesting full sync with pact members...")
    BloodPact_StartManualSyncWatch()
    BloodPact_SyncEngine:SendSyncRequest()
    BloodPact_SyncEngine:BroadcastAllDeaths()
    BloodPact_SyncEngine:BroadcastRosterSnapshot(true)
    BloodPact_SyncEngine:BroadcastAllDungeonCompletions()
    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
    BloodPact_Logger:Print("Sync request sent. You'll see feedback in ~12 seconds.")
end

function BloodPact_CommandHandler:ShowStatus()
    BloodPact_Logger:Print("=== Blood Pact Status ===")
    local displayName = BloodPact_AccountIdentity:GetDisplayName() or "None"
    BloodPact_Logger:Print("Display Name: " .. displayName)
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
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact sync       - Manually sync with pact members (if roster is missing)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact setmain  - Set current character as main hardcore (for roster)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp setname <name> - Set your display name (shown in pact UI)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact wipe     - Wipe all death data (requires confirmation)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bloodpact help     - Show this help message")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp errors        - Show recent errors from persistent log")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp clearerrors   - Clear the error log")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp trace         - Toggle addon message tracing")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp dump          - Dump addon state to chat")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp profile       - Show/clear performance profiles")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp deletedeath <char> [n] - Delete death #n (debug, 1=most recent)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp kick <name> - Kick member from pact (owner only, debug)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp dungeondebug   - Dungeon tracking diagnostics")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp simdungeon <id> - Simulate dungeon completion (e.g. simdungeon deadmines)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bp                 - Shortcut for /bloodpact")
end

-- /bp deletedeath <charName> [index] - Delete a death (debug). Index 1 = most recent.
function BloodPact_CommandHandler:HandleDeleteDeath(rest)
    if not rest or string.len(rest) == 0 then
        BloodPact_Logger:Print("Usage: /bp deletedeath <charName> [index]")
        BloodPact_Logger:Print("  Index 1 = most recent death. Omit for most recent.")
        return
    end

    local args = {}
    for word in string.gfind(rest, "%S+") do
        table.insert(args, word)
    end

    local charName = args[1]
    local index = tonumber(args[2]) or 1

    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        BloodPact_Logger:Print("No death data.")
        return
    end

    if not BloodPactAccountDB.deaths[charName] then
        BloodPact_Logger:Print("No deaths for character '" .. tostring(charName) .. "'.")
        return
    end

    if BloodPact_DeathDataManager:DeleteDeath(charName, index) then
        BloodPact_Logger:Print("Deleted death #" .. tostring(index) .. " for " .. charName .. ".")
        if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
            BloodPact_MainFrame:Refresh()
        end
    else
        BloodPact_Logger:Print("Failed to delete. Check character name and index (1-" ..
            tostring(table.getn(BloodPact_DeathDataManager:GetDeaths(charName))) .. ").")
    end
end

-- /bp kick <name> - Kick a member from the pact (owner only, debug). Accepts display name or account ID.
function BloodPact_CommandHandler:HandleKick(nameInput)
    if not nameInput or string.len(nameInput) == 0 then
        BloodPact_Logger:Print("Usage: /bp kick <name>")
        BloodPact_Logger:Print("  Use display name or account ID of the member to kick.")
        return
    end

    if not BloodPact_PactManager:IsInPact() then
        BloodPact_Logger:Print("You must be in a pact first.")
        return
    end

    if not BloodPact_PactManager:IsOwner() then
        BloodPact_Logger:Print("Only the pact owner can kick members.")
        return
    end

    local accountID = BloodPact_PactManager:ResolveMemberIdentifier(nameInput)
    if not accountID then
        BloodPact_Logger:Print("Cannot find member '" .. nameInput .. "' (try display name or account ID).")
        return
    end

    if BloodPact_PactManager:KickMember(accountID) then
        local displayName = BloodPact_AccountIdentity and BloodPact_AccountIdentity:GetDisplayNameFor(accountID) or accountID
        BloodPact_Logger:Print("Kicked '" .. displayName .. "' from the pact.")
        if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
            BloodPact_MainFrame:Refresh()
        end
    else
        BloodPact_Logger:Print("Cannot kick (cannot kick yourself).")
    end
end

function BloodPact_CommandHandler:ShowErrors()
    local errors = BloodPact_Debug:GetErrorLog()
    local count = table.getn(errors)
    if count == 0 then
        BloodPact_Logger:Print("No errors in log.")
        return
    end
    BloodPact_Logger:Print("=== Error Log (" .. tostring(count) .. " entries) ===")
    local startIdx = math.max(1, count - 9)
    for i = startIdx, count do
        local e = errors[i]
        local ts = date("%H:%M:%S", e.timestamp)
        local countStr = (e.count and e.count > 1) and (" (x" .. tostring(e.count) .. ")") or ""
        local catStr = e.category and ("[" .. e.category .. "] ") or ""
        BloodPact_Logger:Print("[" .. ts .. "] " .. catStr .. tostring(e.message) .. countStr)
    end
    if startIdx > 1 then
        BloodPact_Logger:Print("(" .. tostring(startIdx - 1) .. " older entries hidden)")
    end
end

function BloodPact_CommandHandler:HandleProfile(sub)
    if sub == "clear" then
        BloodPact_Debug:ClearProfiles()
        BloodPact_Logger:Print("Profile data cleared.")
    elseif sub == "show" or sub == "" then
        local profiles = BloodPact_Debug:GetProfiles()
        local hasAny = false
        for label, data in pairs(profiles) do
            hasAny = true
            BloodPact_Logger:Print(label .. ": " .. tostring(data.callCount or 0) .. " calls, " ..
                string.format("%.1f", data.totalMs or 0) .. "ms total")
        end
        if not hasAny then BloodPact_Logger:Print("No profile data.") end
    else
        BloodPact_Logger:Print("Usage: /bp profile [show|clear]")
    end
end

-- ============================================================
-- Dungeon Tracking Diagnostics
-- ============================================================

-- /bp dungeondebug - Show dungeon tracking module status and diagnostics
function BloodPact_CommandHandler:HandleDungeonDebug()
    BloodPact_Logger:Print("=== Dungeon Tracking Debug ===")

    -- Module existence
    BloodPact_Logger:Print("DungeonTracker: " .. (BloodPact_DungeonTracker and "OK" or "NIL (file failed to load)"))
    BloodPact_Logger:Print("DungeonDetailOverlay: " .. (BloodPact_DungeonDetailOverlay and "OK" or "NIL (file failed to load)"))
    BloodPact_Logger:Print("DungeonDataManager: " .. (BloodPact_DungeonDataManager and "OK" or "NIL"))
    BloodPact_Logger:Print("BLOODPACT_DUNGEON_DATABASE: " .. (BLOODPACT_DUNGEON_DATABASE and tostring(table.getn(BLOODPACT_DUNGEON_DATABASE)) .. " dungeons" or "NIL"))
    BloodPact_Logger:Print("BLOODPACT_DUNGEON_GROUPS: " .. (BLOODPACT_DUNGEON_GROUPS and tostring(table.getn(BLOODPACT_DUNGEON_GROUPS)) .. " groups" or "NIL"))

    -- Boss lookup (DungeonTracker builds this from database at init)
    if BloodPact_DungeonTracker and BloodPact_DungeonTracker.GetBossLookupCount then
        local count = BloodPact_DungeonTracker:GetBossLookupCount()
        BloodPact_Logger:Print("Boss lookup entries: " .. tostring(count) .. (count == 0 and " (empty - check BLOODPACT_DUNGEON_DATABASE)" or ""))
    end

    -- Zone APIs (used for verification)
    local zone1 = (GetRealZoneText and GetRealZoneText()) or "N/A"
    local zone2 = (GetZoneText and GetZoneText()) or "N/A"
    BloodPact_Logger:Print("Current zone - GetRealZoneText: '" .. zone1 .. "' | GetZoneText: '" .. zone2 .. "'")

    -- Local completions count
    local charName = UnitName("player")
    local count = 0
    if charName and BloodPactAccountDB and BloodPactAccountDB.dungeonCompletions then
        local comps = BloodPactAccountDB.dungeonCompletions[charName]
        if comps then for _ in pairs(comps) do count = count + 1 end end
    end
    BloodPact_Logger:Print("Your completions (this char): " .. tostring(count))

    BloodPact_Logger:Print("Tip: Use /bp debug then kill a boss to see raw combat log format.")
    BloodPact_Logger:Print("Tip: Use /bp simdungeon deadmines to test completion pipeline.")
end

-- /bp simdungeon <dungeonID> - Simulate a dungeon completion (bypasses combat log)
function BloodPact_CommandHandler:HandleSimDungeon(rest)
    if not rest or string.len(string.gsub(rest, "^%s*(.-)%s*$", "%1")) == 0 then
        BloodPact_Logger:Print("Usage: /bp simdungeon <dungeonID>")
        BloodPact_Logger:Print("Examples: deadmines, ragefire, wailing_caverns, sfk")
        return
    end

    local dungeonID = string.gsub(rest, "^%s*(.-)%s*$", "%1")
    local charName = UnitName("player")
    if not charName then
        BloodPact_Logger:Print("Could not get character name.")
        return
    end

    if not BloodPactAccountDB then
        BloodPact_Logger:Print("SavedVariables not loaded yet. Try again after login.")
        return
    end

    local completion = {
        dungeonID     = dungeonID,
        timestamp     = time(),
        characterName = charName,
    }

    -- Use DungeonDataManager if available, else fallback to direct DB write (when module fails to load)
    local recorded = false
    if BloodPact_DungeonDataManager and BloodPact_DungeonDataManager.RecordCompletion then
        recorded = BloodPact_DungeonDataManager:RecordCompletion(completion)
    else
        -- Fallback: record directly (DungeonDataManager.lua may have failed to load)
        if not BloodPactAccountDB.dungeonCompletions then
            BloodPactAccountDB.dungeonCompletions = {}
        end
        if not BloodPactAccountDB.dungeonCompletions[charName] then
            BloodPactAccountDB.dungeonCompletions[charName] = {}
        end
        if not BloodPactAccountDB.dungeonCompletions[charName][dungeonID] then
            BloodPactAccountDB.dungeonCompletions[charName][dungeonID] = completion.timestamp
            recorded = true
        end
    end

    if not recorded then
        BloodPact_Logger:Print("Already completed " .. dungeonID .. " on this character.")
        return
    end

    BloodPact_Logger:Print("[SIM] " .. charName .. " completed " .. dungeonID .. "!")

    -- Broadcast to pact if in one
    if BloodPact_PactManager and BloodPact_PactManager:IsInPact() and BloodPact_SyncEngine then
        BloodPact_SyncEngine:BroadcastDungeonCompletion(completion)
        BloodPact_Logger:Print("[SIM] Broadcast to pact.")
    end

    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
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
        characterName       = charName,
        characterInstanceID = BloodPact_CharacterIdentity:GenerateInstanceID(),
        level               = level,
        timestamp     = time() - math.random(0, 300),
        serverTime    = date("%Y-%m-%d %H:%M:%S"),
        zoneName      = zone,
        subZoneName   = "",
        killerName    = killer,
        killerLevel   = math.random(math.max(1, level - 2), level + 5),
        killerType    = "NPC",
        killerAbility = "Simulated Death",
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
