-- Blood Pact - Roster Data Manager
-- Collects current character snapshot (level, class, gold, professions) for roster display

BloodPact_RosterDataManager = {}

-- ============================================================
-- Snapshot Collection
-- ============================================================

-- Collect current character's roster snapshot (level, class, gold, professions)
-- Returns a table suitable for serialization and display
function BloodPact_RosterDataManager:GetCurrentSnapshot()
    local charName = UnitName("player")
    if not charName then return nil end

    local _, classEn = UnitClass("player")
    local level = UnitLevel("player") or 0
    local copper = GetMoney() or 0

    local prof1, prof1Level, prof2, prof2Level = self:GetProfessionLevels()

    return {
        characterName = charName,
        class         = classEn or "",
        level         = level,
        copper        = copper,
        profession1   = prof1 or "",
        profession1Level = prof1Level or 0,
        profession2   = prof2 or "",
        profession2Level = prof2Level or 0,
        timestamp     = time()
    }
end

-- Get the two primary profession names and levels (vanilla 1.12 skill API)
-- Returns prof1Name, prof1Level, prof2Name, prof2Level
function BloodPact_RosterDataManager:GetProfessionLevels()
    if not GetNumSkillLines or not GetSkillLineInfo then
        return nil, 0, nil, 0
    end

    local professions = {}
    local numLines = GetNumSkillLines()
    if not numLines or numLines <= 0 then return nil, 0, nil, 0 end

    -- Vanilla 1.12: GetSkillLineInfo(index) returns skillName, isHeader, isExpanded, skillRank, ...
    for i = 1, numLines do
        local ok, name, isHeader, expanded, rank, temp, mod, maxRank = pcall(GetSkillLineInfo, i)
        if ok and name and not isHeader and rank and rank > 0 then
            -- Filter to primary professions (exclude First Aid, Cooking, Fishing - secondary)
            local lower = string.lower(name or "")
            if lower ~= "first aid" and lower ~= "cooking" and lower ~= "fishing" then
                table.insert(professions, { name = name, level = rank })
            end
        end
    end

    -- Return first two primary professions
    local p1 = professions[1]
    local p2 = professions[2]
    return (p1 and p1.name), (p1 and p1.level) or 0,
           (p2 and p2.name), (p2 and p2.level) or 0
end

-- Check if current character is the account's main (or if main not set, treat as main)
function BloodPact_RosterDataManager:IsCurrentCharacterMain()
    if not BloodPactAccountDB or not BloodPactAccountDB.config then return true end
    local main = BloodPactAccountDB.config.mainCharacter
    if not main or main == "" then return true end
    return UnitName("player") == main
end

-- Get list of character names known to this account (from deaths + characters)
function BloodPact_RosterDataManager:GetKnownCharacters()
    local chars = {}
    if BloodPactAccountDB and BloodPactAccountDB.deaths then
        for charName, _ in pairs(BloodPactAccountDB.deaths) do
            chars[charName] = true
        end
    end
    if BloodPactAccountDB and BloodPactAccountDB.characters then
        for charName, _ in pairs(BloodPactAccountDB.characters) do
            chars[charName] = true
        end
    end
    local list = {}
    for k, _ in pairs(chars) do
        table.insert(list, k)
    end
    table.sort(list)
    return list
end

-- Set main character (persisted in config)
function BloodPact_RosterDataManager:SetMainCharacter(charName)
    if not BloodPactAccountDB then return false end
    if not BloodPactAccountDB.config then
        BloodPactAccountDB.config = {}
    end
    BloodPactAccountDB.config.mainCharacter = charName or nil
    return true
end

-- Get main character name
function BloodPact_RosterDataManager:GetMainCharacter()
    if not BloodPactAccountDB or not BloodPactAccountDB.config then return nil end
    return BloodPactAccountDB.config.mainCharacter
end
