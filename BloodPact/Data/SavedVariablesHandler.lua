-- Blood Pact - SavedVariables Handler
-- Handles loading, validation, corruption repair, and schema migration

BloodPact_SavedVariablesHandler = {}

function BloodPact_SavedVariablesHandler:OnVariablesLoaded()
    -- Initialize account identity (creates DB if first launch)
    BloodPact_AccountIdentity:Initialize()

    -- Validate and repair data integrity
    self:ValidateData()

    -- Migrate schema if needed
    self:MigrateSchema()
end

function BloodPact_SavedVariablesHandler:ValidateData()
    if not BloodPactAccountDB then return end

    -- Ensure version field exists
    if not BloodPactAccountDB.version then
        BloodPact_Logger:Warning("SavedVariables missing version field. Attempting recovery.")
        BloodPactAccountDB.version = BLOODPACT_SCHEMA_VERSION
    end

    -- Ensure required top-level fields exist
    if not BloodPactAccountDB.deaths then
        BloodPactAccountDB.deaths = {}
    end
    if not BloodPactAccountDB.characters then
        BloodPactAccountDB.characters = {}
    end
    if not BloodPactAccountDB.dungeonCompletions then
        BloodPactAccountDB.dungeonCompletions = {}
    end
    if not BloodPactAccountDB.questLog then
        BloodPactAccountDB.questLog = {}
    end
    if not BloodPactAccountDB.config then
        BloodPactAccountDB.config = {
            uiScale            = 1.0,
            showTimeline       = true,
            manualHardcoreFlag = true,
            windowX            = nil,
            windowY            = nil,
            windowAlpha        = 1.0
        }
    end
    if BloodPactAccountDB.config.windowAlpha == nil then
        BloodPactAccountDB.config.windowAlpha = 1.0
    end
    if BloodPactAccountDB.config.mainCharacter == nil then
        BloodPactAccountDB.config.mainCharacter = nil  -- explicitly nil = use current char
    end
    -- Migrate: ensure displayName exists (default to accountID)
    if (BloodPactAccountDB.config.displayName == nil or BloodPactAccountDB.config.displayName == "") and BloodPactAccountDB.accountID then
        BloodPactAccountDB.config.displayName = BloodPactAccountDB.accountID
    end

    -- Ensure debug storage exists
    if not BloodPactAccountDB.debug then
        BloodPactAccountDB.debug = { errorLog = {} }
    end
    if not BloodPactAccountDB.debug.errorLog then
        BloodPactAccountDB.debug.errorLog = {}
    end

    -- Validate death records
    if BloodPactAccountDB.deaths then
        for charName, deathList in pairs(BloodPactAccountDB.deaths) do
            if type(deathList) ~= "table" then
                BloodPact_Logger:Warning("Corrupted death list for character '" .. tostring(charName) .. "'. Resetting.")
                BloodPactAccountDB.deaths[charName] = {}
            else
                -- Validate individual records
                local i = table.getn(deathList)
                while i >= 1 do
                    local death = deathList[i]
                    if type(death) ~= "table" or
                       not death.characterName or
                       not death.timestamp or
                       not death.level then
                        BloodPact_Logger:Warning("Removed corrupted death record for '" .. tostring(charName) .. "'.")
                        table.remove(deathList, i)
                    else
                        -- Backfill characterInstanceID for legacy records (same-name char support)
                        if not death.characterInstanceID and BloodPact_CharacterIdentity then
                            death.characterInstanceID = "legacy_" .. tostring(death.timestamp or 0) .. "_" ..
                                string.format("%04d", math.random(1000, 9999))
                        end
                    end
                    i = i - 1
                end
            end
        end
    end

    -- Validate pact structure
    if BloodPactAccountDB.pact then
        local pact = BloodPactAccountDB.pact
        if not pact.joinCode or not pact.pactName or not pact.ownerAccountID then
            BloodPact_Logger:Warning("Corrupted pact data. Clearing pact membership.")
            BloodPactAccountDB.pact = nil
        else
            -- Ensure sub-tables exist
            if not pact.members then pact.members = {} end
            if not pact.syncedDeaths then pact.syncedDeaths = {} end
            if not pact.rosterSnapshots then pact.rosterSnapshots = {} end
            if not pact.syncedDungeonCompletions then pact.syncedDungeonCompletions = {} end
            if not pact.syncedQuestLogs then pact.syncedQuestLogs = {} end
        end
    end
end

function BloodPact_SavedVariablesHandler:MigrateSchema()
    if not BloodPactAccountDB then return end

    local currentVersion = BloodPactAccountDB.version or 1

    -- Future migrations go here:
    -- if currentVersion < 2 then
    --     self:MigrateV1ToV2()
    --     BloodPactAccountDB.version = 2
    --     currentVersion = 2
    -- end
end

function BloodPact_SavedVariablesHandler:OnPlayerLogout()
    -- SavedVariables are automatically written by WoW on logout.
    -- No explicit flush needed. Use this for any final cleanup.
    BloodPact_Logger:Info("Saving Blood Pact data...")
end
