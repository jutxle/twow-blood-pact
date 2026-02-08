-- Blood Pact - Death Data Manager
-- Handles CRUD operations for death records

BloodPact_DeathDataManager = {
    dirtyFlag = false
}

-- Record a new death for the current account
function BloodPact_DeathDataManager:RecordDeath(deathRecord)
    if not BloodPactAccountDB then
        BloodPact_Logger:Error("Cannot record death: database not initialized.")
        return false
    end

    local charName = deathRecord.characterName
    if not charName then
        BloodPact_Logger:Error("Cannot record death: no character name in record.")
        return false
    end

    -- Ensure deaths table exists
    if not BloodPactAccountDB.deaths then
        BloodPactAccountDB.deaths = {}
    end
    if not BloodPactAccountDB.deaths[charName] then
        BloodPactAccountDB.deaths[charName] = {}
    end

    -- Add the death record
    table.insert(BloodPactAccountDB.deaths[charName], deathRecord)

    -- Enforce size limit
    self:EnforceSizeLimit(charName)

    -- Mark dirty (will be auto-saved on logout)
    self.dirtyFlag = true

    BloodPact_Logger:Print("Death recorded: " .. charName .. " (Lvl " .. tostring(deathRecord.level) .. ")")

    return true
end

-- Enforce the 25-death-per-character limit
function BloodPact_DeathDataManager:EnforceSizeLimit(charName)
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then return end

    local deathList = BloodPactAccountDB.deaths[charName]
    if not deathList then return end

    -- Remove oldest entries (first in array) until within limit
    while table.getn(deathList) > BLOODPACT_MAX_DEATHS_PER_CHAR do
        table.remove(deathList, 1)
    end
end

-- Get all deaths for a specific character (nil = all characters)
function BloodPact_DeathDataManager:GetDeaths(charName)
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return {}
    end

    if charName then
        return BloodPactAccountDB.deaths[charName] or {}
    end

    -- Return all deaths across all characters
    local allDeaths = {}
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        for _, death in ipairs(deathList) do
            table.insert(allDeaths, death)
        end
    end
    -- Sort by timestamp descending (most recent first)
    table.sort(allDeaths, function(a, b)
        return a.timestamp > b.timestamp
    end)
    return allDeaths
end

-- Get total death count for the account
function BloodPact_DeathDataManager:GetTotalDeaths()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return 0
    end
    local total = 0
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        total = total + table.getn(deathList)
    end
    return total
end

-- Get highest level achieved across all characters
function BloodPact_DeathDataManager:GetHighestLevel()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return 0
    end
    local highest = 0
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        for _, death in ipairs(deathList) do
            if death.level and death.level > highest then
                highest = death.level
            end
        end
    end
    return highest
end

-- Get total copper lost across all deaths
function BloodPact_DeathDataManager:GetTotalCopperLost()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return 0
    end
    local total = 0
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        for _, death in ipairs(deathList) do
            total = total + (death.copperAmount or 0)
        end
    end
    return total
end

-- Get total XP lost across all deaths
function BloodPact_DeathDataManager:GetTotalXPLost()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return 0
    end
    local total = 0
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        for _, death in ipairs(deathList) do
            total = total + (death.totalXP or 0)
        end
    end
    return total
end

-- Get list of character names with their highest death-level and death count
function BloodPact_DeathDataManager:GetCharacterSummaries()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return {}
    end
    local summaries = {}
    for charName, deathList in pairs(BloodPactAccountDB.deaths) do
        local highestLevel = 0
        for _, death in ipairs(deathList) do
            if death.level and death.level > highestLevel then
                highestLevel = death.level
            end
        end
        table.insert(summaries, {
            characterName = charName,
            deathCount    = table.getn(deathList),
            highestLevel  = highestLevel
        })
    end
    -- Sort by highest level descending
    table.sort(summaries, function(a, b)
        return a.highestLevel > b.highestLevel
    end)
    return summaries
end

-- Wipe all death data (preserves account ID, pact, and config)
function BloodPact_DeathDataManager:WipeAllDeaths()
    if not BloodPactAccountDB then return end
    BloodPactAccountDB.deaths = {}
    self.dirtyFlag = true
    BloodPact_Logger:Print("All death data has been wiped.")
end

-- Store synced deaths from a pact member
function BloodPact_DeathDataManager:StoreSyncedDeath(memberAccountID, deathRecord)
    if not BloodPactAccountDB or not BloodPactAccountDB.pact then return end
    if not BloodPactAccountDB.pact.syncedDeaths then
        BloodPactAccountDB.pact.syncedDeaths = {}
    end

    local syncedDeaths = BloodPactAccountDB.pact.syncedDeaths
    if not syncedDeaths[memberAccountID] then
        syncedDeaths[memberAccountID] = {}
    end

    local charName = deathRecord.characterName
    if not syncedDeaths[memberAccountID][charName] then
        syncedDeaths[memberAccountID][charName] = {}
    end

    -- Check for duplicate (same character, timestamp within 10s, same level)
    local charDeaths = syncedDeaths[memberAccountID][charName]
    for _, existing in ipairs(charDeaths) do
        if math.abs(existing.timestamp - deathRecord.timestamp) <= 10 and
           existing.level == deathRecord.level then
            -- Already have this death
            return false
        end
    end

    table.insert(charDeaths, deathRecord)

    -- Enforce limit per character per member
    while table.getn(charDeaths) > BLOODPACT_MAX_DEATHS_PER_CHAR do
        table.remove(charDeaths, 1)
    end

    self.dirtyFlag = true
    return true
end

-- Get all deaths from all pact members (including self), sorted by timestamp
function BloodPact_DeathDataManager:GetAllPactDeaths()
    local allDeaths = {}

    -- Own deaths
    local ownID = BloodPact_AccountIdentity:GetAccountID()
    for _, deathList in pairs(BloodPactAccountDB.deaths or {}) do
        for _, death in ipairs(deathList) do
            local d = death
            d.ownerAccountID = ownID
            table.insert(allDeaths, d)
        end
    end

    -- Synced deaths from other members
    if BloodPactAccountDB.pact and BloodPactAccountDB.pact.syncedDeaths then
        for memberID, charMap in pairs(BloodPactAccountDB.pact.syncedDeaths) do
            for _, deathList in pairs(charMap) do
                for _, death in ipairs(deathList) do
                    local d = death
                    d.ownerAccountID = memberID
                    table.insert(allDeaths, d)
                end
            end
        end
    end

    table.sort(allDeaths, function(a, b)
        return a.timestamp > b.timestamp
    end)
    return allDeaths
end

-- Convert copper amount to display string "Xg Ys Zc"
function BloodPact_DeathDataManager:FormatCopper(copper)
    if not copper or copper == 0 then return "0c" end
    copper = math.floor(copper)
    local gold   = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop    = math.mod(copper, 100)

    if gold > 0 then
        return gold .. "g " .. silver .. "s " .. cop .. "c"
    elseif silver > 0 then
        return silver .. "s " .. cop .. "c"
    else
        return cop .. "c"
    end
end
