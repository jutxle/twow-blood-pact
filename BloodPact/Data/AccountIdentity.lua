-- Blood Pact - Account Identity
-- Manages the unique account identifier (set once, never changes)

BloodPact_AccountIdentity = {}

function BloodPact_AccountIdentity:Initialize()
    -- BloodPactAccountDB is populated by VARIABLES_LOADED at this point
    if BloodPactAccountDB and BloodPactAccountDB.accountID then
        -- Already initialized
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
        uiScale             = 1.0,
        showTimeline        = true,
        manualHardcoreFlag  = false,
        windowX             = nil,
        windowY             = nil
    }
    BloodPactAccountDB.version = BLOODPACT_SCHEMA_VERSION

    BloodPact_Logger:Print("Welcome to Blood Pact! Your account ID is: " .. charName)
end

function BloodPact_AccountIdentity:GetAccountID()
    if BloodPactAccountDB and BloodPactAccountDB.accountID then
        return BloodPactAccountDB.accountID
    end
    return nil
end
