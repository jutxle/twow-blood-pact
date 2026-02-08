-- Blood Pact - Ownership Manager
-- Handles pact ownership transfer logic when the owner's characters die

BloodPact_OwnershipManager = {}

-- Determine who should become the new pact owner.
-- Criteria: member with highest-level living character;
-- tie-break: longest pact membership (earliest joinedTimestamp).
-- Returns the accountID of the new owner, or nil if no living members.
function BloodPact_OwnershipManager:DetermineNewOwner(members, excludeAccountID)
    if not members then return nil end

    local best = nil
    local bestLevel = -1
    local bestJoinTime = math.huge

    for accountID, member in pairs(members) do
        if accountID ~= excludeAccountID and member.isAlive then
            local lvl = member.highestLevel or 0
            local joined = member.joinedTimestamp or 0

            if lvl > bestLevel or (lvl == bestLevel and joined < bestJoinTime) then
                bestLevel = lvl
                bestJoinTime = joined
                best = accountID
            end
        end
    end

    return best
end

-- Called when the current player (who is the pact owner) records a death.
-- Checks if this player now has no living characters and transfers ownership.
function BloodPact_OwnershipManager:OnOwnerDeath()
    if not BloodPactAccountDB or not BloodPactAccountDB.pact then return end

    local pact = BloodPactAccountDB.pact
    local ownerID = pact.ownerAccountID
    local selfID  = BloodPact_AccountIdentity:GetAccountID()

    if ownerID ~= selfID then return end  -- we are not the owner

    -- Check if self still has living characters (simplified: assume dead after this death)
    -- The addon doesn't know about non-dead characters, so we just transfer now.
    local newOwner = self:DetermineNewOwner(pact.members, selfID)

    if newOwner then
        pact.ownerAccountID = newOwner
        BloodPact_Logger:Print("Pact ownership transferred to: " .. newOwner)
        BloodPact_SyncEngine:BroadcastOwnershipTransfer(selfID, newOwner)
    else
        -- All members dead; pact becomes dormant
        pact.ownerAccountID = nil
        BloodPact_Logger:Print("All pact members have fallen. The " .. pact.pactName .. " is now dormant.")
        BloodPact_SyncEngine:BroadcastOwnershipTransfer(selfID, "")
    end
end

-- Called when an ownership transfer message is received from the network
function BloodPact_OwnershipManager:OnTransferReceived(oldOwnerID, newOwnerID)
    if not BloodPactAccountDB or not BloodPactAccountDB.pact then return end
    local pact = BloodPactAccountDB.pact

    -- Only apply if this is for our pact and the old owner matches
    if pact.ownerAccountID ~= oldOwnerID then return end

    if newOwnerID and string.len(newOwnerID) > 0 then
        pact.ownerAccountID = newOwnerID
        BloodPact_Logger:Print("Pact ownership transferred to: " .. newOwnerID)
    else
        pact.ownerAccountID = nil
        BloodPact_Logger:Print("Pact is now dormant (all members have fallen).")
    end
end
