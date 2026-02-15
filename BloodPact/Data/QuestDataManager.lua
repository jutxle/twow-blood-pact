-- Blood Pact - Quest Data Manager
-- Manages local quest log scanning, storage, synced quest logs from pact members,
-- and shared quest computation

BloodPact_QuestDataManager = {}

-- ============================================================
-- Local Quest Log Scanning
-- ============================================================

-- Read the current player's quest log from the WoW API.
-- Returns an array of quest title strings (excluding headers).
function BloodPact_QuestDataManager:ScanLocalQuestLog()
    local quests = {}
    local numEntries = GetNumQuestLogEntries()
    if not numEntries or numEntries == 0 then return quests end

    for i = 1, numEntries do
        local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(i)
        if questTitle and not isHeader then
            table.insert(quests, questTitle)
        end
    end
    return quests
end

-- Scan the quest log and store it in saved variables for the current character.
-- Returns the quest list.
function BloodPact_QuestDataManager:UpdateLocalQuestLog()
    if not BloodPactAccountDB then return {} end

    local quests = self:ScanLocalQuestLog()
    local charName = UnitName("player")
    if not charName then return quests end

    if not BloodPactAccountDB.questLog then
        BloodPactAccountDB.questLog = {}
    end

    BloodPactAccountDB.questLog[charName] = {
        quests    = quests,
        timestamp = time()
    }
    return quests
end

-- Get the local player's current quest list (from saved vars, or live scan as fallback).
function BloodPact_QuestDataManager:GetLocalQuests()
    local charName = UnitName("player")
    if charName and BloodPactAccountDB and BloodPactAccountDB.questLog
       and BloodPactAccountDB.questLog[charName] then
        return BloodPactAccountDB.questLog[charName].quests or {}
    end
    -- Fallback: scan live
    return self:ScanLocalQuestLog()
end

-- ============================================================
-- Synced Quest Log Storage
-- ============================================================

-- Store a synced quest log from a pact member (full replacement).
-- data = { characterName = "Bob", quests = {...}, timestamp = T }
function BloodPact_QuestDataManager:StoreSyncedQuestLog(senderID, data)
    if not BloodPactAccountDB or not BloodPactAccountDB.pact then return end

    if not BloodPactAccountDB.pact.syncedQuestLogs then
        BloodPactAccountDB.pact.syncedQuestLogs = {}
    end

    BloodPactAccountDB.pact.syncedQuestLogs[senderID] = {
        characterName = data.characterName or "",
        quests        = data.quests or {},
        timestamp     = data.timestamp or 0
    }
end

-- Get the quest log for a pact member.
-- For self: returns current local quest log.
-- For others: returns last-known synced data (may be from an offline member).
-- Returns { characterName, quests = {}, timestamp } or nil.
function BloodPact_QuestDataManager:GetMemberQuestLog(accountID)
    local selfID = BloodPact_AccountIdentity and BloodPact_AccountIdentity:GetAccountID()
    if accountID == selfID then
        local charName = UnitName("player")
        local quests = self:GetLocalQuests()
        return { characterName = charName, quests = quests, timestamp = time() }
    end

    if BloodPactAccountDB and BloodPactAccountDB.pact
       and BloodPactAccountDB.pact.syncedQuestLogs then
        return BloodPactAccountDB.pact.syncedQuestLogs[accountID]
    end
    return nil
end

-- Remove quest log data for a member who has been kicked or left.
function BloodPact_QuestDataManager:RemoveMemberQuestLog(accountID)
    if BloodPactAccountDB and BloodPactAccountDB.pact
       and BloodPactAccountDB.pact.syncedQuestLogs then
        BloodPactAccountDB.pact.syncedQuestLogs[accountID] = nil
    end
end

-- ============================================================
-- Shared Quest Computation
-- ============================================================

-- Compute quests shared between the local player and pact members.
-- Returns a sorted array of { questTitle = "X", members = { accountID1, accountID2, ... } }
-- Only includes quests that the local player also has in their log.
function BloodPact_QuestDataManager:GetSharedQuests()
    local localQuests = self:GetLocalQuests()

    -- Build a set for O(1) lookup
    local localSet = {}
    for _, q in ipairs(localQuests) do
        localSet[q] = true
    end

    local selfID = BloodPact_AccountIdentity and BloodPact_AccountIdentity:GetAccountID()
    local questMembers = {}  -- { [questTitle] = { accountID1, accountID2, ... } }

    if BloodPactAccountDB and BloodPactAccountDB.pact and BloodPactAccountDB.pact.members then
        for accountID, _ in pairs(BloodPactAccountDB.pact.members) do
            if accountID ~= selfID then
                local memberLog = self:GetMemberQuestLog(accountID)
                if memberLog and memberLog.quests then
                    for _, q in ipairs(memberLog.quests) do
                        if localSet[q] then
                            if not questMembers[q] then
                                questMembers[q] = {}
                            end
                            table.insert(questMembers[q], accountID)
                        end
                    end
                end
            end
        end
    end

    -- Convert to sorted array
    local result = {}
    for questTitle, memberList in pairs(questMembers) do
        table.insert(result, { questTitle = questTitle, members = memberList })
    end
    table.sort(result, function(a, b) return a.questTitle < b.questTitle end)
    return result
end
