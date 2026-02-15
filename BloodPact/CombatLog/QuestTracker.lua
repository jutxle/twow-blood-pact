-- Blood Pact - Quest Tracker
-- Listens for QUEST_LOG_UPDATE events, throttles broadcasts, and triggers quest log syncing.
-- The 3-second cooldown prevents spamming the sync channel since QUEST_LOG_UPDATE
-- fires very frequently (on objective progress, quest accept/abandon/complete, zone change, etc.).

BloodPact_QuestTracker = {}

local questBroadcastPending = false
local questBroadcastTimer = 0

-- ============================================================
-- Event Handling
-- ============================================================

-- Called from Core.lua when QUEST_LOG_UPDATE fires.
-- Marks that we need to broadcast (actual broadcast deferred to Tick).
function BloodPact_QuestTracker:OnQuestLogUpdate()
    questBroadcastPending = true
    questBroadcastTimer = 0
end

-- Called from Core.lua OnUpdate accumulator (every 0.5s).
-- Waits for the cooldown to expire, then scans and broadcasts.
function BloodPact_QuestTracker:Tick(elapsed)
    if not questBroadcastPending then return end

    questBroadcastTimer = questBroadcastTimer + elapsed
    if questBroadcastTimer < BLOODPACT_QUEST_BROADCAST_COOLDOWN then return end

    -- Cooldown expired: scan and broadcast
    questBroadcastPending = false
    questBroadcastTimer = 0

    -- Update local quest log in saved variables
    if BloodPact_QuestDataManager then
        BloodPact_QuestDataManager:UpdateLocalQuestLog()
    end

    -- Broadcast to pact if applicable
    if BloodPact_PactManager:IsInPact() and BloodPact_SyncEngine then
        BloodPact_SyncEngine:BroadcastQuestLog()
    end

    -- Refresh UI if open
    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end
