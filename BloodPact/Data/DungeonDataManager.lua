-- Blood Pact - Dungeon Data Manager
-- Handles CRUD operations for dungeon completion records

BloodPact_DungeonDataManager = {}

-- Record a dungeon completion for a local character.
-- completion = { dungeonID, timestamp, characterName }
-- Only stores the first completion per character + dungeon (no duplicates).
function BloodPact_DungeonDataManager:RecordCompletion(completion)
    if not BloodPactAccountDB then return false end
    if not completion or not completion.dungeonID or not completion.characterName then
        return false
    end

    if not BloodPactAccountDB.dungeonCompletions then
        BloodPactAccountDB.dungeonCompletions = {}
    end

    local charName = completion.characterName
    if not BloodPactAccountDB.dungeonCompletions[charName] then
        BloodPactAccountDB.dungeonCompletions[charName] = {}
    end

    -- Only record first completion
    if BloodPactAccountDB.dungeonCompletions[charName][completion.dungeonID] then
        return false
    end

    BloodPactAccountDB.dungeonCompletions[charName][completion.dungeonID] = completion.timestamp or time()
    return true
end

-- Get completions for a specific local character.
-- Returns { [dungeonID] = timestamp } or empty table.
function BloodPact_DungeonDataManager:GetCompletions(charName)
    if not BloodPactAccountDB or not BloodPactAccountDB.dungeonCompletions then
        return {}
    end
    return BloodPactAccountDB.dungeonCompletions[charName] or {}
end

-- Get all local completions across all characters.
-- Returns { [charName] = { [dungeonID] = timestamp } }
function BloodPact_DungeonDataManager:GetAllLocalCompletions()
    if not BloodPactAccountDB or not BloodPactAccountDB.dungeonCompletions then
        return {}
    end
    return BloodPactAccountDB.dungeonCompletions
end

-- Store a single synced dungeon completion from a pact member.
-- data = { senderID, characterName, dungeonID, timestamp }
function BloodPact_DungeonDataManager:StoreSyncedCompletion(senderID, data)
    if not BloodPactAccountDB or not BloodPactAccountDB.pact then return end
    if not data or not data.dungeonID then return end

    if not BloodPactAccountDB.pact.syncedDungeonCompletions then
        BloodPactAccountDB.pact.syncedDungeonCompletions = {}
    end

    local synced = BloodPactAccountDB.pact.syncedDungeonCompletions
    if not synced[senderID] then
        synced[senderID] = {}
    end

    -- Only store first completion per dungeon
    if not synced[senderID][data.dungeonID] then
        synced[senderID][data.dungeonID] = data.timestamp or 0
    end
end

-- Store bulk synced dungeon completions from a pact member.
-- completions = { [dungeonID] = timestamp, ... }
function BloodPact_DungeonDataManager:StoreSyncedCompletions(senderID, completions)
    if not BloodPactAccountDB or not BloodPactAccountDB.pact then return end
    if not completions then return end

    if not BloodPactAccountDB.pact.syncedDungeonCompletions then
        BloodPactAccountDB.pact.syncedDungeonCompletions = {}
    end

    local synced = BloodPactAccountDB.pact.syncedDungeonCompletions
    if not synced[senderID] then
        synced[senderID] = {}
    end

    for dungeonID, ts in pairs(completions) do
        -- Only store if we don't already have a completion for this dungeon
        if not synced[senderID][dungeonID] then
            synced[senderID][dungeonID] = ts
        end
    end
end

-- Get dungeon completions for a pact member (by accountID).
-- For own account: merges all local character completions into a flat map.
-- For other accounts: returns synced data.
-- Returns { [dungeonID] = timestamp }
function BloodPact_DungeonDataManager:GetMemberCompletions(accountID)
    if not BloodPactAccountDB then return {} end

    local selfID = BloodPact_AccountIdentity and BloodPact_AccountIdentity:GetAccountID()

    if accountID == selfID then
        -- Merge all local character completions (earliest timestamp wins)
        local merged = {}
        local allLocal = self:GetAllLocalCompletions()
        for _, charCompletions in pairs(allLocal) do
            for dungeonID, ts in pairs(charCompletions) do
                if not merged[dungeonID] or ts < merged[dungeonID] then
                    merged[dungeonID] = ts
                end
            end
        end
        return merged
    end

    -- Other pact member: return synced data
    if not BloodPactAccountDB.pact or not BloodPactAccountDB.pact.syncedDungeonCompletions then
        return {}
    end

    return BloodPactAccountDB.pact.syncedDungeonCompletions[accountID] or {}
end

-- Get the count of completed dungeons for a pact member.
function BloodPact_DungeonDataManager:GetCompletionCount(accountID)
    local completions = self:GetMemberCompletions(accountID)
    local count = 0
    for _ in pairs(completions) do
        count = count + 1
    end
    return count
end

-- Get a flat table of all local completions for broadcast.
-- Returns { [dungeonID] = timestamp } merged across all characters.
function BloodPact_DungeonDataManager:GetLocalCompletionsForBroadcast()
    local merged = {}
    local allLocal = self:GetAllLocalCompletions()
    for _, charCompletions in pairs(allLocal) do
        for dungeonID, ts in pairs(charCompletions) do
            if not merged[dungeonID] or ts < merged[dungeonID] then
                merged[dungeonID] = ts
            end
        end
    end
    return merged
end
