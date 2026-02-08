-- Blood Pact - Pact Manager
-- Handles pact creation, joining, member roster, and incoming sync events

BloodPact_PactManager = {}

-- ============================================================
-- Pact Status Checks
-- ============================================================

function BloodPact_PactManager:IsInPact()
    return BloodPactAccountDB ~= nil and BloodPactAccountDB.pact ~= nil
end

function BloodPact_PactManager:IsOwner()
    if not self:IsInPact() then return false end
    return BloodPactAccountDB.pact.ownerAccountID == BloodPact_AccountIdentity:GetAccountID()
end

function BloodPact_PactManager:GetPactCode()
    if not self:IsInPact() then return nil end
    return BloodPactAccountDB.pact.joinCode
end

-- ============================================================
-- Pact Creation
-- ============================================================

function BloodPact_PactManager:CreatePact(pactName)
    if not pactName or string.len(pactName) == 0 then
        BloodPact_Logger:Print("Pact name cannot be empty.")
        return false
    end
    if string.len(pactName) > 32 then
        BloodPact_Logger:Print("Pact name must be 32 characters or fewer.")
        return false
    end
    if self:IsInPact() then
        BloodPact_Logger:Print("You are already in a Blood Pact. Leave first.")
        return false
    end

    local selfID = BloodPact_AccountIdentity:GetAccountID()
    local code   = BloodPact_JoinCodeGenerator:GenerateCode()
    local now    = time()

    BloodPactAccountDB.pact = {
        pactName         = pactName,
        joinCode         = code,
        ownerAccountID   = selfID,
        createdTimestamp = now,
        members          = {
            [selfID] = {
                accountID      = selfID,
                highestLevel   = BloodPact_DeathDataManager:GetHighestLevel(),
                deathCount     = BloodPact_DeathDataManager:GetTotalDeaths(),
                isAlive        = true,
                joinedTimestamp = now
            }
        },
        syncedDeaths = {}
    }

    BloodPact_Logger:Print("Blood Pact created: |cFFFF6600" .. pactName .. "|r")
    BloodPact_Logger:Print("Join Code: |cFFFFAA00" .. code .. "|r  (share with friends!)")

    -- Refresh UI
    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end

    return true
end

-- ============================================================
-- Pact Joining
-- ============================================================

function BloodPact_PactManager:RequestJoin(code)
    code = string.upper(code)
    if not BloodPact_JoinCodeGenerator:ValidateCodeFormat(code) then
        BloodPact_Logger:Print("|cFFFF4444Invalid join code format.|r")
        return
    end

    -- Store pending join code temporarily
    BloodPact_PactManager._pendingJoinCode = code
    BloodPact_Logger:Print("Sending join request for code: " .. code .. " ...")
    BloodPact_Logger:Print("Waiting for pact members to respond (up to " .. BLOODPACT_JOIN_TIMEOUT .. "s)...")

    -- Broadcast join request on all available channels
    local msg = BloodPact_Serialization:SerializeJoinRequest(
        BloodPact_AccountIdentity:GetAccountID(), code
    )
    BloodPact_SyncEngine:BroadcastRaw(msg)

    -- Start timeout watchdog
    BloodPact_StartJoinTimeout()
end

-- Called when no response received within timeout
function BloodPact_PactManager:OnJoinTimeout()
    if BloodPact_PactManager._pendingJoinCode then
        BloodPact_Logger:Print("|cFFFF4444No pact members responded.|r Make sure at least one member is online.")
        BloodPact_PactManager._pendingJoinCode = nil
    end
end

-- Called by SyncEngine when a JOIN_REQUEST message is received from another player
function BloodPact_PactManager:OnJoinRequest(senderID, pactCode)
    if not self:IsInPact() then return end
    if BloodPactAccountDB.pact.joinCode ~= pactCode then return end

    -- Anyone in the pact can respond with pact metadata
    local pact = BloodPactAccountDB.pact
    local msg = BloodPact_Serialization:SerializeJoinResponse(
        pact.ownerAccountID,
        pact.joinCode,
        pact.pactName,
        pact.createdTimestamp,
        senderID
    )
    BloodPact_SyncEngine:BroadcastRaw(msg)

    -- If we are pact owner, also register the new member
    if self:IsOwner() then
        self:AddMember(senderID)
    end
end

-- Called by SyncEngine when a JOIN_RESPONSE message is received
function BloodPact_PactManager:OnJoinResponse(data)
    -- Only process if we have a pending join for this code
    if BloodPact_PactManager._pendingJoinCode ~= data.pactCode then return end
    if self:IsInPact() then return end  -- already joined (maybe duplicate response)

    BloodPact_CancelJoinTimeout()
    BloodPact_PactManager._pendingJoinCode = nil

    local selfID = BloodPact_AccountIdentity:GetAccountID()
    local now    = time()

    -- Create local pact record
    BloodPactAccountDB.pact = {
        pactName         = data.pactName,
        joinCode         = data.pactCode,
        ownerAccountID   = data.ownerAccountID,
        createdTimestamp = data.createdTimestamp,
        members          = {
            [selfID] = {
                accountID       = selfID,
                highestLevel    = BloodPact_DeathDataManager:GetHighestLevel(),
                deathCount      = BloodPact_DeathDataManager:GetTotalDeaths(),
                isAlive         = true,
                joinedTimestamp = now
            }
        },
        syncedDeaths = {}
    }

    BloodPact_Logger:Print("Successfully joined: |cFFFF6600" .. data.pactName .. "|r")
    BloodPact_Logger:Print("Syncing pact data with members...")

    -- Request full data sync from the responder
    BloodPact_SyncEngine:SendSyncRequest()

    -- Share our own death history with pact members
    BloodPact_SyncEngine:BroadcastAllDeaths()

    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end

-- ============================================================
-- Member Management
-- ============================================================

function BloodPact_PactManager:AddMember(accountID)
    if not self:IsInPact() then return end
    local members = BloodPactAccountDB.pact.members
    if members[accountID] then return end  -- already a member

    members[accountID] = {
        accountID       = accountID,
        highestLevel    = 0,
        deathCount      = 0,
        isAlive         = true,
        joinedTimestamp = time()
    }
end

function BloodPact_PactManager:UpdateMemberStats(accountID, deathRecord)
    if not self:IsInPact() then return end
    local members = BloodPactAccountDB.pact.members
    if not members[accountID] then
        self:AddMember(accountID)
    end

    local member = members[accountID]
    member.deathCount = (member.deathCount or 0) + 1
    if deathRecord.level and deathRecord.level > (member.highestLevel or 0) then
        member.highestLevel = deathRecord.level
    end
end

-- ============================================================
-- Incoming Sync Events
-- ============================================================

-- Called when a death announcement arrives from a pact member
function BloodPact_PactManager:OnMemberDeath(senderID, deathRecord)
    if not self:IsInPact() then return end
    if not BloodPactAccountDB.pact.members then return end

    -- Store the synced death
    BloodPact_DeathDataManager:StoreSyncedDeath(senderID, deathRecord)

    -- Update member stats
    self:UpdateMemberStats(senderID, deathRecord)

    -- Notify player
    BloodPact_Logger:Print("|cFFFF4444[Pact]|r " .. senderID .. "'s " ..
        (deathRecord.characterName or "?") .. " (Lvl " .. tostring(deathRecord.level or 0) ..
        ") has fallen in " .. (deathRecord.zoneName or "?") .. ".")

    -- Check ownership transfer if sender was pact owner
    if BloodPactAccountDB.pact.ownerAccountID == senderID then
        -- Mark owner as deceased (simplified)
        if BloodPactAccountDB.pact.members[senderID] then
            BloodPactAccountDB.pact.members[senderID].isAlive = false
        end
    end

    -- Refresh UI if visible
    if BloodPact_MainFrame and BloodPact_MainFrame:IsVisible() then
        BloodPact_MainFrame:Refresh()
    end
end

-- Called when a sync request arrives (someone wants our death data)
function BloodPact_PactManager:OnSyncRequest(senderID)
    if not self:IsInPact() then return end
    BloodPact_SyncEngine:BroadcastAllDeaths()
end

-- Called when ownership transfer arrives
function BloodPact_PactManager:OnOwnershipTransfer(data)
    BloodPact_OwnershipManager:OnTransferReceived(data.oldOwnerID, data.newOwnerID)
end

-- ============================================================
-- Dormancy Check
-- ============================================================

function BloodPact_PactManager:IsDormant()
    if not self:IsInPact() then return false end
    return BloodPactAccountDB.pact.ownerAccountID == nil
end
