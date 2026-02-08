-- Blood Pact - Death Detector
-- State machine for detecting and confirming player deaths
--
-- States:
--   IDLE       -> watching for signals
--   SUSPECTED  -> CHAT_MSG_COMBAT_HOSTILE_DEATH matched player name, waiting for PLAYER_DEAD
--   COLLECTING -> death confirmed (from either signal), gathering context
--   COMPLETE   -> death recorded and broadcast

BloodPact_DeathDetector = {
    STATE_IDLE       = 0,
    STATE_SUSPECTED  = 1,
    STATE_COLLECTING = 2,

    state            = 0,  -- current state (IDLE)
    suspectTimer     = 0,  -- accumulates elapsed time in SUSPECTED state
    cachedKillerName = nil,
    cachedKillerLevel = nil,
    cachedKillerType  = nil
}

-- Tick called from Core.lua OnUpdate accumulator
function BloodPact_DeathDetector:Tick(elapsed)
    if self.state == self.STATE_SUSPECTED then
        self.suspectTimer = self.suspectTimer + elapsed
        if self.suspectTimer > BLOODPACT_DEATH_CONFIRM_WINDOW then
            -- No PLAYER_DEAD arrived in time; likely a pet/NPC death
            BloodPact_Logger:Info("Death suspect timed out (likely not player).")
            self:Reset()
        end
    end
end

-- Called when CHAT_MSG_COMBAT_HOSTILE_DEATH fires
function BloodPact_DeathDetector:OnCombatDeathMessage(msg)
    if self.state ~= self.STATE_IDLE then return end

    if BloodPact_Parser:IsPlayerDeathMessage(msg) then
        self.state        = self.STATE_SUSPECTED
        self.suspectTimer = 0
        -- Cache the last known attacker
        self.cachedKillerName  = BloodPact_Parser:GetLastAttacker()
        self.cachedKillerLevel = nil
        self.cachedKillerType  = self.cachedKillerName and "NPC" or "Unknown"
        BloodPact_Logger:Info("Death suspected from combat log.")
    end
end

-- Called when CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS fires (attacker tracking)
function BloodPact_DeathDetector:OnCreatureHitsPlayer(msg)
    local attacker = BloodPact_Parser:ParseAttackerFromHitMessage(msg)
    if attacker then
        BloodPact_Parser:RecordAttacker(attacker)
    end
end

-- Called when PLAYER_DEAD event fires
function BloodPact_DeathDetector:OnPlayerDead()
    if self.state == self.STATE_SUSPECTED then
        -- Confirmed death with prior combat log signal
        BloodPact_Logger:Info("Death confirmed (PLAYER_DEAD after combat log signal).")
        self.state = self.STATE_COLLECTING
        self:ConfirmAndLogDeath()
    elseif self.state == self.STATE_IDLE then
        -- PLAYER_DEAD without prior signal = environmental death (fall, drown, fatigue)
        BloodPact_Logger:Info("Death confirmed (PLAYER_DEAD, environmental).")
        self.cachedKillerName  = nil
        self.cachedKillerLevel = nil
        self.cachedKillerType  = "Environment"
        self.state = self.STATE_COLLECTING
        self:ConfirmAndLogDeath()
    end
    -- If STATE_COLLECTING or already processing, ignore duplicate events
end

-- Finalize and record the death
function BloodPact_DeathDetector:ConfirmAndLogDeath()
    -- Validate hardcore status before recording
    if not self:IsHardcoreCharacter() then
        BloodPact_Logger:Info("Death ignored: character is not hardcore.")
        self:Reset()
        return
    end

    -- Build complete death record
    local deathRecord = BloodPact_DataExtractor:BuildDeathRecord(
        self.cachedKillerName,
        self.cachedKillerLevel,
        self.cachedKillerType
    )

    -- Save to local database
    BloodPact_DeathDataManager:RecordDeath(deathRecord)

    -- Broadcast to pact if applicable
    if BloodPact_PactManager:IsInPact() then
        BloodPact_SyncEngine:BroadcastDeath(deathRecord)
    end

    -- Refresh UI if open
    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end

    -- Reset state
    self:Reset()
end

-- Check if current character is hardcore
-- Three-tier fallback: Title API -> manual flag
function BloodPact_DeathDetector:IsHardcoreCharacter()
    -- Method 1: Try title API (Turtle WoW custom, may not exist in base 1.12)
    if GetNumTitles then
        local numTitles = GetNumTitles()
        for i = 1, numTitles do
            local titleName = GetTitleName(i)
            if titleName and string.find(titleName, "Still Alive") then
                return true
            end
        end
        -- Title API exists but "Still Alive" not found
        -- Fall through to manual flag check
    end

    -- Method 2: Manual hardcore flag set by user in Settings
    if BloodPactAccountDB and BloodPactAccountDB.config then
        if BloodPactAccountDB.config.manualHardcoreFlag == true then
            return true
        end
    end

    return false
end

-- Reset state machine to IDLE
function BloodPact_DeathDetector:Reset()
    self.state             = self.STATE_IDLE
    self.suspectTimer      = 0
    self.cachedKillerName  = nil
    self.cachedKillerLevel = nil
    self.cachedKillerType  = nil
    BloodPact_Parser:ClearAttackerBuffer()
end
