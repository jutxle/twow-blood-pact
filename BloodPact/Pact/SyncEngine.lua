-- Blood Pact - Sync Engine
-- Handles addon message sending, receiving, chunking, and routing

BloodPact_SyncEngine = {}

-- Message queue
local messageQueue = {}

-- Chunk reassembly buffer: key = senderID .. "_" .. msgID
-- value = {chunks={}, totalChunks=N, receivedCount=N, timestamp=T}
local chunkBuffer = {}

-- Deduplication cache: key = senderID .. "_" .. timestamp, value = true
local dedupCache = {}
local dedupCacheSize = 0

-- Rolling message ID for outgoing chunked messages
local outgoingMsgID = 0

-- ============================================================
-- Initialization
-- ============================================================

function BloodPact_SyncEngine:Initialize()
    messageQueue = {}
    chunkBuffer = {}
    dedupCache = {}
    dedupCacheSize = 0
    outgoingMsgID = math.random(1, 9999)
end

-- ============================================================
-- Sending
-- ============================================================

-- Broadcast a death record to all pact members
function BloodPact_SyncEngine:BroadcastDeath(deathRecord)
    if not BloodPact_PactManager:IsInPact() then return end
    local selfID   = BloodPact_AccountIdentity:GetAccountID()
    local pactCode = BloodPact_PactManager:GetPactCode()

    local msg = BloodPact_Serialization:SerializeDeathAnnounce(selfID, pactCode, deathRecord)
    self:QueueMessage(msg)
end

-- Broadcast an ownership transfer notification
function BloodPact_SyncEngine:BroadcastOwnershipTransfer(oldOwnerID, newOwnerID)
    if not BloodPact_PactManager:IsInPact() then return end
    local pactCode = BloodPact_PactManager:GetPactCode()
    local msg = BloodPact_Serialization:SerializeOwnershipTransfer(pactCode, oldOwnerID, newOwnerID)
    self:QueueMessage(msg)
end

-- Send all our local deaths to pact members (for sync on join or login)
function BloodPact_SyncEngine:BroadcastAllDeaths()
    if not BloodPact_PactManager:IsInPact() then return end
    local selfID   = BloodPact_AccountIdentity:GetAccountID()
    local pactCode = BloodPact_PactManager:GetPactCode()

    for _, deathList in pairs(BloodPactAccountDB.deaths or {}) do
        for _, death in ipairs(deathList) do
            local msg = BloodPact_Serialization:SerializeDeathAnnounce(selfID, pactCode, death)
            self:QueueMessage(msg)
        end
    end
end

-- Send a sync request (asking others to send us their deaths)
function BloodPact_SyncEngine:SendSyncRequest()
    if not BloodPact_PactManager:IsInPact() then return end
    local selfID   = BloodPact_AccountIdentity:GetAccountID()
    local pactCode = BloodPact_PactManager:GetPactCode()
    local msg = BloodPact_Serialization:SerializeSyncRequest(selfID, pactCode)
    self:QueueMessage(msg)
end

-- Broadcast a raw pre-serialized message (for join request/response)
function BloodPact_SyncEngine:BroadcastRaw(msg)
    self:QueueMessage(msg)
end

-- Add message to send queue
function BloodPact_SyncEngine:QueueMessage(msg)
    if string.len(msg) <= BLOODPACT_MSG_CHUNK_SIZE then
        table.insert(messageQueue, msg)
    else
        -- Split into chunks
        self:ChunkAndQueue(msg)
    end
end

-- Split a large message into chunks and queue each chunk
function BloodPact_SyncEngine:ChunkAndQueue(msg)
    outgoingMsgID = outgoingMsgID + 1
    local selfID   = BloodPact_AccountIdentity:GetAccountID() or "?"
    local pactCode = (BloodPact_PactManager:IsInPact() and BloodPact_PactManager:GetPactCode()) or "00000000"

    local chunkSize = BLOODPACT_MSG_CHUNK_SIZE
    local totalChunks = math.ceil(string.len(msg) / chunkSize)

    for i = 1, totalChunks do
        local startIdx = (i - 1) * chunkSize + 1
        local endIdx   = math.min(i * chunkSize, string.len(msg))
        local chunk    = string.sub(msg, startIdx, endIdx)

        local chunkMsg = BloodPact_Serialization:SerializeChunk(
            selfID, pactCode, outgoingMsgID, i, totalChunks, chunk
        )
        table.insert(messageQueue, chunkMsg)
    end
end

-- ============================================================
-- Queue Flushing (called from Core.lua OnUpdate)
-- ============================================================

function BloodPact_SyncEngine:FlushMessageQueue()
    if table.getn(messageQueue) == 0 then return end
    if not BloodPact_RateLimiter:CanSend() then return end

    local msg = table.remove(messageQueue, 1)
    self:SendOnAllChannels(msg)
    BloodPact_RateLimiter:RecordSend()
end

function BloodPact_SyncEngine:SendOnAllChannels(msg)
    -- Truncate to 254 bytes (WoW 1.12 limit is 255, keep 1 byte safe margin)
    if string.len(msg) > 254 then
        BloodPact_Logger:Warning("Message truncated (too long): " .. string.len(msg) .. " bytes")
        msg = string.sub(msg, 1, 254)
    end

    local sent = false

    if IsInGuild and IsInGuild() then
        SendAddonMessage(BLOODPACT_ADDON_PREFIX, msg, "GUILD")
        sent = true
    end

    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if numRaid > 0 then
        SendAddonMessage(BLOODPACT_ADDON_PREFIX, msg, "RAID")
        sent = true
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        SendAddonMessage(BLOODPACT_ADDON_PREFIX, msg, "PARTY")
        sent = true
    end

    if not sent then
        BloodPact_Logger:Info("No channel available for addon message (not in guild/party/raid).")
    end
end

-- ============================================================
-- Receiving (called from Core.lua OnEvent CHAT_MSG_ADDON)
-- ============================================================

function BloodPact_SyncEngine:OnAddonMessage(msg, channel, sender)
    if not msg then return end

    -- Get message type
    local msgType = BloodPact_Serialization:GetMessageType(msg)
    if not msgType then return end

    -- Route to appropriate handler
    if msgType == "DA" then
        self:HandleDeathAnnounce(msg, sender)
    elseif msgType == "JR" then
        self:HandleJoinRequest(msg, sender)
    elseif msgType == "JR2" then
        self:HandleJoinResponse(msg, sender)
    elseif msgType == "OT" then
        self:HandleOwnershipTransfer(msg, sender)
    elseif msgType == "SR" then
        self:HandleSyncRequest(msg, sender)
    elseif msgType == "CK" then
        self:HandleChunk(msg, sender)
    end
end

-- ============================================================
-- Message Handlers
-- ============================================================

function BloodPact_SyncEngine:HandleDeathAnnounce(msg, sender)
    local senderID, pactCode, record = BloodPact_Serialization:DeserializeDeathAnnounce(msg)
    if not senderID or not record then return end
    if not self:IsMessageForOurPact(pactCode) then return end
    if self:IsDuplicate(senderID, record.timestamp) then return end
    self:MarkSeen(senderID, record.timestamp)

    -- Don't process our own deaths (we already recorded them locally)
    if senderID == BloodPact_AccountIdentity:GetAccountID() then return end

    BloodPact_PactManager:OnMemberDeath(senderID, record)
end

function BloodPact_SyncEngine:HandleJoinRequest(msg, sender)
    local senderID, pactCode = BloodPact_Serialization:DeserializeJoinRequest(msg)
    if not senderID or not pactCode then return end
    BloodPact_PactManager:OnJoinRequest(senderID, pactCode)
end

function BloodPact_SyncEngine:HandleJoinResponse(msg, sender)
    local data = BloodPact_Serialization:DeserializeJoinResponse(msg)
    if not data then return end
    BloodPact_PactManager:OnJoinResponse(data)
end

function BloodPact_SyncEngine:HandleOwnershipTransfer(msg, sender)
    local data = BloodPact_Serialization:DeserializeOwnershipTransfer(msg)
    if not data then return end
    if not self:IsMessageForOurPact(data.pactCode) then return end
    BloodPact_PactManager:OnOwnershipTransfer(data)
end

function BloodPact_SyncEngine:HandleSyncRequest(msg, sender)
    local senderID, pactCode = BloodPact_Serialization:DeserializeSyncRequest(msg)
    if not senderID or not pactCode then return end
    if not self:IsMessageForOurPact(pactCode) then return end
    if senderID == BloodPact_AccountIdentity:GetAccountID() then return end
    BloodPact_PactManager:OnSyncRequest(senderID)
end

function BloodPact_SyncEngine:HandleChunk(msg, sender)
    local data = BloodPact_Serialization:DeserializeChunk(msg)
    if not data then return end
    if not self:IsMessageForOurPact(data.pactCode) then return end

    local key = (data.senderID or "?") .. "_" .. tostring(data.msgID)
    if not chunkBuffer[key] then
        chunkBuffer[key] = {
            chunks        = {},
            totalChunks   = data.totalChunks,
            receivedCount = 0,
            timestamp     = GetTime()
        }
    end

    local buf = chunkBuffer[key]
    if not buf.chunks[data.chunkIdx] then
        buf.chunks[data.chunkIdx] = data.payload
        buf.receivedCount = buf.receivedCount + 1
    end

    if buf.receivedCount >= buf.totalChunks then
        -- Reassemble
        local fullMsg = ""
        for i = 1, buf.totalChunks do
            fullMsg = fullMsg .. (buf.chunks[i] or "")
        end
        chunkBuffer[key] = nil
        -- Re-process the reassembled message
        self:OnAddonMessage(fullMsg, "CHUNK", data.senderID)
    end
end

-- ============================================================
-- Chunk Buffer Cleanup (called from Core.lua OnUpdate)
-- ============================================================

function BloodPact_SyncEngine:CleanExpiredChunks()
    local now = GetTime()
    local toRemove = {}
    for key, buf in pairs(chunkBuffer) do
        if now - buf.timestamp > BLOODPACT_CHUNK_TIMEOUT then
            table.insert(toRemove, key)
        end
    end
    for _, key in ipairs(toRemove) do
        BloodPact_Logger:Warning("Chunk buffer expired for key: " .. key)
        chunkBuffer[key] = nil
    end
end

-- ============================================================
-- Utilities
-- ============================================================

function BloodPact_SyncEngine:IsMessageForOurPact(pactCode)
    if not BloodPact_PactManager:IsInPact() then
        -- Still allow join requests even when not in a pact? No — JR/JR2 handlers
        -- check pact membership themselves. For non-pact scenarios, return false here
        -- except for JR handling (handled separately).
        return false
    end
    return BloodPactAccountDB.pact.joinCode == pactCode
end

function BloodPact_SyncEngine:IsDuplicate(senderID, timestamp)
    local key = (senderID or "?") .. "_" .. tostring(timestamp)
    return dedupCache[key] == true
end

function BloodPact_SyncEngine:MarkSeen(senderID, timestamp)
    local key = (senderID or "?") .. "_" .. tostring(timestamp)
    if not dedupCache[key] then
        dedupCache[key] = true
        dedupCacheSize = dedupCacheSize + 1

        -- Prune if cache grows too large
        if dedupCacheSize > 200 then
            dedupCache = {}
            dedupCacheSize = 0
        end
    end
end
