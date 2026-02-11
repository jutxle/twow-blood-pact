-- Blood Pact - Account Identity
-- Manages the unique account identifier (set once, never changes)
-- and the user-facing Display Name (shown in UI; accountID used only for syncing)

BloodPact_AccountIdentity = {}

function BloodPact_AccountIdentity:Initialize()
    -- BloodPactAccountDB is populated by VARIABLES_LOADED at this point
    if BloodPactAccountDB and BloodPactAccountDB.accountID then
        -- Already initialized - ensure displayName exists (migration)
        if not BloodPactAccountDB.config then
            BloodPactAccountDB.config = {}
        end
        if BloodPactAccountDB.config.displayName == nil or BloodPactAccountDB.config.displayName == "" then
            BloodPactAccountDB.config.displayName = BloodPactAccountDB.accountID
        end
        BloodPact_Logger:Info("Account ID: " .. BloodPactAccountDB.accountID)
        return
    end

    -- First-ever launch: generate account ID from current character name
    local charName = UnitName("player")
    if not charName then
        BloodPact_Logger:Error("Could not determine character name for account initialization.")
        return
    end

    if not BloodPactAccountDB then
        BloodPactAccountDB = {}
    end

    BloodPactAccountDB.accountID              = charName
    BloodPactAccountDB.accountCreatedTimestamp = time()
    BloodPactAccountDB.deaths                 = {}
    BloodPactAccountDB.pact                   = nil
    BloodPactAccountDB.config                 = {
        displayName        = charName,
        uiScale             = 1.0,
        showTimeline        = true,
        manualHardcoreFlag  = false,
        windowX             = nil,
        windowY             = nil,
        windowAlpha         = 1.0
    }
    BloodPactAccountDB.version = BLOODPACT_SCHEMA_VERSION

    BloodPact_Logger:Print("Welcome to Blood Pact! Your display name is: " .. charName)
end

function BloodPact_AccountIdentity:GetAccountID()
    if BloodPactAccountDB and BloodPactAccountDB.accountID then
        return BloodPactAccountDB.accountID
    end
    return nil
end

-- Get the display name for this account (user-configurable, shown in UI)
function BloodPact_AccountIdentity:GetDisplayName()
    if BloodPactAccountDB and BloodPactAccountDB.config and BloodPactAccountDB.config.displayName then
        local dn = BloodPactAccountDB.config.displayName
        if string.len(dn) > 0 then return dn end
    end
    return self:GetAccountID() or "Unknown"
end

-- Set the display name for this account
function BloodPact_AccountIdentity:SetDisplayName(name)
    if not BloodPactAccountDB then return false end
    if not BloodPactAccountDB.config then
        BloodPactAccountDB.config = {}
    end
    -- Trim and limit length (32 chars like pact names)
    local clean = name and string.gsub(name, "^%s*(.-)%s*$", "%1") or ""
    if string.len(clean) > 32 then clean = string.sub(clean, 1, 32) end
    BloodPactAccountDB.config.displayName = (clean ~= "") and clean or self:GetAccountID()
    return true
end

-- Get the display name for any account ID (self or pact member). Used across UI.
-- Fallback order: displayName -> roster characterName -> accountID
function BloodPact_AccountIdentity:GetDisplayNameFor(accountID)
    if not accountID then return "?" end

    local selfID = self:GetAccountID()
    if accountID == selfID then
        return self:GetDisplayName()
    end

    -- Check roster snapshots for pact members
    if BloodPactAccountDB and BloodPactAccountDB.pact and BloodPactAccountDB.pact.rosterSnapshots then
        local snapshot = BloodPactAccountDB.pact.rosterSnapshots[accountID]
        if snapshot then
            if snapshot.displayName and string.len(snapshot.displayName) > 0 then
                return snapshot.displayName
            end
            if snapshot.characterName and string.len(snapshot.characterName) > 0 then
                return snapshot.characterName
            end
        end
    end

    return accountID
end
