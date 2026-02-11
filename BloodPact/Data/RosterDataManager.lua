-- Blood Pact - Roster Data Manager
-- Collects current character snapshot (level, class, gold, professions, talents) for roster display

BloodPact_RosterDataManager = {}

-- Known profession names (excludes class spell schools like Affliction, Demonology, Destruction)
-- Used to filter skill list so we don't confuse warlock/mage spell schools with professions
local PROFESSION_NAMES = {
    ["Mining"] = true, ["Herbalism"] = true, ["Skinning"] = true,
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Engineering"] = true,
    ["Leatherworking"] = true, ["Tailoring"] = true, ["Enchanting"] = true,
    ["First Aid"] = true, ["Cooking"] = true, ["Fishing"] = true,
    ["Jewelcrafting"] = true,  -- Turtle WoW
}

-- ============================================================
-- Snapshot Collection
-- ============================================================

-- Collect current character's roster snapshot (level, class, gold, professions, talents)
-- Returns a table suitable for serialization and display
function BloodPact_RosterDataManager:GetCurrentSnapshot()
    local charName = UnitName("player")
    if not charName then return nil end

    local _, classEn = UnitClass("player")
    local level = UnitLevel("player") or 0
    local copper = GetMoney() or 0

    local prof1, prof1Level, prof2, prof2Level = self:GetProfessionLevels()
    local talentTabs = self:GetTalentTabs()

    local displayName = BloodPact_AccountIdentity and BloodPact_AccountIdentity:GetDisplayName() or charName
    return {
        characterName = charName,
        displayName   = displayName,
        class         = classEn or "",
        level         = level,
        copper        = copper,
        profession1   = prof1 or "",
        profession1Level = prof1Level or 0,
        profession2   = prof2 or "",
        profession2Level = prof2Level or 0,
        talentTabs    = talentTabs or {},
        timestamp     = time()
    }
end

-- Get profession names and levels (vanilla 1.12 / Turtle WoW skill API)
-- Returns prof1Name, prof1Level, prof2Name, prof2Level
-- Only includes actual professions (Mining, Herbalism, etc.) - NOT class spell schools
function BloodPact_RosterDataManager:GetProfessionLevels()
    local getNum = GetNumSkillLines or GetNumSkills
    if not getNum or not GetSkillLineInfo then
        return nil, 0, nil, 0
    end

    local professions = {}
    local numLines = getNum()
    if not numLines or numLines <= 0 then return nil, 0, nil, 0 end

    local function isProfession(name)
        return name and PROFESSION_NAMES[name]
    end

    -- Vanilla 1.12: GetSkillLineInfo(index) returns skillName, isHeader, isExpanded, skillRank, ...
    for i = 1, numLines do
        local ok, name, isHeader, expanded, rank, temp, mod, maxRank = pcall(GetSkillLineInfo, i)
        if ok and name and name ~= "" then
            local isHeaderVal = (isHeader == 1 or isHeader == true)
            if not isHeaderVal and isProfession(name) then
                local lvl = (rank and rank > 0) and rank or 0
                table.insert(professions, { name = name, level = lvl })
            end
        end
    end

    -- Fallback: try 0-based indexing if 1-based yielded nothing
    if table.getn(professions) == 0 then
        for i = 0, numLines - 1 do
            local ok, name, isHeader, expanded, rank = pcall(GetSkillLineInfo, i)
            if ok and name and name ~= "" and isProfession(name) then
                local isHeaderVal = (isHeader == 1 or isHeader == true)
                if not isHeaderVal then
                    local lvl = (rank and rank > 0) and rank or 0
                    table.insert(professions, { name = name, level = lvl })
                end
            end
        end
    end

    local p1 = professions[1]
    local p2 = professions[2]
    return (p1 and p1.name), (p1 and p1.level) or 0,
           (p2 and p2.name), (p2 and p2.level) or 0
end

-- Get talent tab names and points spent (vanilla 1.12 GetNumTalentTabs / GetTalentTabInfo)
-- Returns { {name, pointsSpent}, ... } for all 3 talent trees
function BloodPact_RosterDataManager:GetTalentTabs()
    if not GetNumTalentTabs or not GetTalentTabInfo then return {} end

    local tabs = {}
    local numTabs = GetNumTalentTabs()
    if not numTabs or numTabs <= 0 then return tabs end

    for i = 1, numTabs do
        local ok, name, texture, pointsSpent, fileName = pcall(GetTalentTabInfo, i)
        if ok and name and name ~= "" then
            table.insert(tabs, {
                name = name,
                pointsSpent = (pointsSpent and pointsSpent > 0) and pointsSpent or 0
            })
        end
    end
    return tabs
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
