-- Blood Pact - Core
-- Main addon frame, event registration, and OnUpdate timer accumulator
-- Loaded last so all modules are available

-- Create the main addon frame for event handling
BloodPactFrame = CreateFrame("Frame", "BloodPactFrame", UIParent)

-- OnUpdate timer accumulators (in seconds)
local BP_Timers = {
    deathTick    = 0,   -- death detector tick (0.1s interval)
    syncFlush    = 0,   -- message queue flush (0.5s interval)
    chunkTimeout = 0,   -- chunk buffer cleanup (5s interval)
    syncRequest  = 0,   -- post-login sync request delay
    joinTimeout  = 0,   -- pact join request timeout
}

local BP_LoginSyncPending = false
local BP_JoinTimeoutActive = false
local BP_LastUpdateTime = 0

-- ============================================================
-- Event Handler
-- ============================================================

function BloodPact_OnEvent(event, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if event == "VARIABLES_LOADED" then
        BloodPact_SavedVariablesHandler:OnVariablesLoaded()
        BloodPact_SyncEngine:Initialize()

        -- Initialize UI modules (deferred until data is available)
        BloodPact_MainFrame:Create()
        BloodPact_PersonalDashboard:Initialize()
        BloodPact_PersonalTimeline:Initialize()
        BloodPact_PactDashboard:Initialize()
        BloodPact_PactTimeline:Initialize()
        BloodPact_Settings:Initialize()

        -- If we are in a pact, schedule a sync request after login
        if BloodPact_PactManager:IsInPact() then
            BP_LoginSyncPending = true
            BP_Timers.syncRequest = 0
        end

    elseif event == "PLAYER_LOGOUT" then
        BloodPact_SavedVariablesHandler:OnPlayerLogout()
        BloodPact_DeathDataManager.dirtyFlag = false

    elseif event == "PLAYER_DEAD" then
        BloodPact_DeathDetector:OnPlayerDead()

    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        BloodPact_DeathDetector:OnCombatDeathMessage(a1)

    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" then
        BloodPact_DeathDetector:OnCreatureHitsPlayer(a1)

    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" then
        BloodPact_DeathDetector:OnCreatureHitsPlayer(a1)

    elseif event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        -- Spell damage from creatures: "X's SpellName hits you for N"
        BloodPact_DeathDetector:OnCreatureHitsPlayer(a1)

    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        -- DoT damage: "You suffer N from X's SpellName"
        BloodPact_DeathDetector:OnCreatureHitsPlayer(a1)

    elseif event == "CHAT_MSG_ADDON" then
        -- a1=prefix, a2=message, a3=channel, a4=sender
        if a1 == BLOODPACT_ADDON_PREFIX then
            BloodPact_SyncEngine:OnAddonMessage(a2, a3, a4)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Track current character level on login/zone change
        BloodPact_UpdateCharacterLevel()

    elseif event == "PLAYER_LEVEL_UP" then
        -- a1 = new level
        BloodPact_UpdateCharacterLevel()
        -- Broadcast roster when we level (so pact sees updated level)
        if BloodPact_PactManager:IsInPact() and BloodPact_RosterDataManager and BloodPact_RosterDataManager:IsCurrentCharacterMain() then
            BloodPact_SyncEngine:BroadcastRosterSnapshot()
        end
    end
end

BloodPactFrame:SetScript("OnEvent", function()
    BloodPact_OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
end)

-- ============================================================
-- OnUpdate - Timer Accumulator
-- ============================================================

BloodPactFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if BP_LastUpdateTime == 0 then BP_LastUpdateTime = now end
    local elapsed = now - BP_LastUpdateTime
    BP_LastUpdateTime = now

    -- Death detector tick (every 0.1s)
    BP_Timers.deathTick = BP_Timers.deathTick + elapsed
    if BP_Timers.deathTick >= BLOODPACT_SUSPECT_TIMER_INTERVAL then
        BP_Timers.deathTick = 0
        BloodPact_DeathDetector:Tick(BLOODPACT_SUSPECT_TIMER_INTERVAL)
    end

    -- Sync engine message queue flush (every 0.5s)
    BP_Timers.syncFlush = BP_Timers.syncFlush + elapsed
    if BP_Timers.syncFlush >= BLOODPACT_RATE_LIMIT_INTERVAL then
        BP_Timers.syncFlush = 0
        BloodPact_SyncEngine:FlushMessageQueue()
    end

    -- Chunk buffer timeout cleanup (every 5s)
    BP_Timers.chunkTimeout = BP_Timers.chunkTimeout + elapsed
    if BP_Timers.chunkTimeout >= 5.0 then
        BP_Timers.chunkTimeout = 0
        BloodPact_SyncEngine:CleanExpiredChunks()
    end

    -- Post-login sync request (after BLOODPACT_SYNC_REQUEST_DELAY seconds)
    if BP_LoginSyncPending then
        BP_Timers.syncRequest = BP_Timers.syncRequest + elapsed
        if BP_Timers.syncRequest >= BLOODPACT_SYNC_REQUEST_DELAY then
            BP_LoginSyncPending = false
            BloodPact_SyncEngine:SendSyncRequest()
            BloodPact_SyncEngine:BroadcastRosterSnapshot()
        end
    end

    -- Pact join timeout
    if BP_JoinTimeoutActive then
        BP_Timers.joinTimeout = BP_Timers.joinTimeout + elapsed
        if BP_Timers.joinTimeout >= BLOODPACT_JOIN_TIMEOUT then
            BP_JoinTimeoutActive = false
            BloodPact_PactManager:OnJoinTimeout()
        end
    end
end)

-- ============================================================
-- Event Registration
-- ============================================================

BloodPactFrame:RegisterEvent("VARIABLES_LOADED")
BloodPactFrame:RegisterEvent("PLAYER_LOGOUT")
BloodPactFrame:RegisterEvent("PLAYER_DEAD")
BloodPactFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BloodPactFrame:RegisterEvent("PLAYER_LEVEL_UP")
BloodPactFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
BloodPactFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
BloodPactFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
BloodPactFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
BloodPactFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
BloodPactFrame:RegisterEvent("CHAT_MSG_ADDON")

-- ============================================================
-- Wrap main event/update handlers for error capture
-- ============================================================

if BloodPact_Debug then
    local originalOnEvent = BloodPactFrame:GetScript("OnEvent")
    if originalOnEvent then
        BloodPactFrame:SetScript("OnEvent", function()
            local ok, err = pcall(originalOnEvent)
            if not ok then
                BloodPact_Debug:LogError("[OnEvent:" .. tostring(event) .. "] " .. tostring(err),
                    debugstack and debugstack(2, 8, 0) or nil, "CORE")
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("[BloodPact] ERROR in " .. tostring(event) .. ": " .. tostring(err))
                end
            end
        end)
    end

    BloodPact_Debug:WrapScript(BloodPactFrame, "OnUpdate")
end

-- ============================================================
-- Initialization
-- ============================================================

-- Seed random number generator once at load time
math.randomseed(time())

-- Register addon message prefix if API available (may not exist in all 1.12 builds)
if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(BLOODPACT_ADDON_PREFIX)
end

-- ============================================================
-- Helper functions exposed for other modules
-- ============================================================

-- Activate the join timeout watchdog
function BloodPact_StartJoinTimeout()
    BP_JoinTimeoutActive = true
    BP_Timers.joinTimeout = 0
end

function BloodPact_CancelJoinTimeout()
    BP_JoinTimeoutActive = false
    BP_Timers.joinTimeout = 0
end

-- Update the current character's level in the characters tracking table
function BloodPact_UpdateCharacterLevel()
    if not BloodPactAccountDB then return end
    if not BloodPactAccountDB.characters then
        BloodPactAccountDB.characters = {}
    end

    local charName = UnitName("player")
    local level = UnitLevel("player")
    if not charName or not level then return end

    BloodPactAccountDB.characters[charName] = {
        level = level,
        lastSeen = time()
    }

    -- Also update pact member highestLevel if we're in a pact
    if BloodPact_PactManager:IsInPact() then
        local selfID = BloodPact_AccountIdentity:GetAccountID()
        local members = BloodPactAccountDB.pact.members
        if members and members[selfID] then
            local highest = BloodPact_DeathDataManager:GetHighestLevel()
            if highest > (members[selfID].highestLevel or 0) then
                members[selfID].highestLevel = highest
            end
        end
    end
end
