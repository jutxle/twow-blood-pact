-- Blood Pact - Dungeon Tracker
-- Detects final boss kills via combat log and records dungeon completions
-- Uses CHAT_MSG_COMBAT_HOSTILE_DEATH event routed from Core.lua

BloodPact_DungeonTracker = {}

-- Reverse lookup: lowercase boss name -> dungeon entry from BLOODPACT_DUNGEON_DATABASE
local bossLookup = {}

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_DungeonTracker:Initialize()
    bossLookup = {}
    if not BLOODPACT_DUNGEON_DATABASE then return end

    for _, dungeon in ipairs(BLOODPACT_DUNGEON_DATABASE) do
        if dungeon.bosses then
            for _, bossName in ipairs(dungeon.bosses) do
                bossLookup[string.lower(bossName)] = dungeon
            end
        end
    end
end

-- Debug: return boss lookup count (for /bp dungeondebug)
function BloodPact_DungeonTracker:GetBossLookupCount()
    local n = 0
    for _ in pairs(bossLookup) do n = n + 1 end
    return n
end

-- ============================================================
-- Boss Kill Detection
-- ============================================================

-- Called from Core.lua when CHAT_MSG_COMBAT_HOSTILE_DEATH fires
function BloodPact_DungeonTracker:OnCombatDeathMessage(msg)
    if not msg then return end

    -- Debug: log raw message format when debug logging enabled (helps verify combat log format)
    if BloodPact_Logger and BloodPact_Logger.currentLevel == BloodPact_Logger.LEVEL.DEBUG then
        BloodPact_Logger:Debug("[DungeonTracker] CHAT_MSG_COMBAT_HOSTILE_DEATH: " .. tostring(msg), "DungeonTracker")
    end

    -- Step 1: Extract the dead entity name
    local deadName = self:ParseDeadEntityName(msg)
    if not deadName then return end

    -- Step 2: Check if the dead entity is a known final boss
    local dungeon = bossLookup[string.lower(deadName)]
    if BloodPact_Logger and BloodPact_Logger.currentLevel == BloodPact_Logger.LEVEL.DEBUG and deadName then
        BloodPact_Logger:Debug("[DungeonTracker] Parsed dead: '" .. deadName .. "' -> boss match: " .. (dungeon and dungeon.name or "none"), "DungeonTracker")
    end
    if not dungeon then return end

    -- Step 3: Verify zone matches the dungeon
    if not self:VerifyZone(dungeon) then
        local zoneA = (GetRealZoneText and GetRealZoneText()) or "?"
        local zoneB = (GetZoneText and GetZoneText()) or "?"
        BloodPact_Logger:Info("Boss '" .. deadName .. "' killed but zone mismatch. Expected: " .. dungeon.zone .. " | GetRealZoneText: " .. zoneA .. " | GetZoneText: " .. zoneB)
        return
    end

    -- Step 4: Record the completion
    local charName = UnitName("player")
    if not charName then return end

    local completion = {
        dungeonID     = dungeon.id,
        timestamp     = time(),
        characterName = charName,
    }

    local recorded = BloodPact_DungeonDataManager:RecordCompletion(completion)
    if not recorded then
        -- Already completed this dungeon on this character
        return
    end

    BloodPact_Logger:Print(charName .. " completed " .. dungeon.name .. "!")

    -- Step 5: Broadcast to pact
    if BloodPact_PactManager:IsInPact() then
        BloodPact_SyncEngine:BroadcastDungeonCompletion(completion)
    end

    -- Step 6: Refresh UI if open
    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end

-- ============================================================
-- Parsing
-- ============================================================

-- Extract the dead entity name from a combat log death message.
-- Formats vary by locale: "X dies.", "X is slain by Y.", "X has been slain by Y."
function BloodPact_DungeonTracker:ParseDeadEntityName(msg)
    if not msg then return nil end
    -- Pattern: "X dies." (NPC death)
    local name = string.match(msg, "^(.+) dies%.$")
    if name then return name end
    -- Pattern: "X is slain by Y."
    name = string.match(msg, "^(.+) is slain by")
    if name then return name end
    -- Pattern: "X has been slain by Y."
    name = string.match(msg, "^(.+) has been slain by")
    if name then return name end
    return nil
end

-- ============================================================
-- Zone Verification
-- ============================================================

-- Verify the player is in the correct zone for the dungeon.
-- Checks primary zone name and alt zone names.
function BloodPact_DungeonTracker:VerifyZone(dungeon)
    local currentZone = (GetRealZoneText and GetRealZoneText()) or ""
    local lowerCurrent = string.lower(currentZone)

    -- Check primary zone
    if lowerCurrent == string.lower(dungeon.zone) then
        return true
    end

    -- Check alternative zone names
    if dungeon.altZones then
        for _, altZone in ipairs(dungeon.altZones) do
            if lowerCurrent == string.lower(altZone) then
                return true
            end
        end
    end

    -- Also try GetZoneText as fallback (some 1.12 builds differ)
    local altCurrent = (GetZoneText and GetZoneText()) or ""
    local lowerAlt = string.lower(altCurrent)

    if lowerAlt == string.lower(dungeon.zone) then
        return true
    end
    if dungeon.altZones then
        for _, altZone in ipairs(dungeon.altZones) do
            if lowerAlt == string.lower(altZone) then
                return true
            end
        end
    end

    return false
end
