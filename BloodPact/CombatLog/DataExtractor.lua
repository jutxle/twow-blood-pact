-- Blood Pact - Data Extractor
-- Extracts character state, location, inventory, and killer data at time of death

BloodPact_DataExtractor = {}

-- Equipment slot ID to name mapping (WoW 1.12)
local SLOT_NAMES = {
    [1]  = "HeadSlot",
    [2]  = "NeckSlot",
    [3]  = "ShoulderSlot",
    [5]  = "ChestSlot",
    [6]  = "WaistSlot",
    [7]  = "LegsSlot",
    [8]  = "FeetSlot",
    [9]  = "WristSlot",
    [10] = "HandsSlot",
    [11] = "Finger0Slot",
    [12] = "Finger1Slot",
    [13] = "Trinket0Slot",
    [14] = "Trinket1Slot",
    [15] = "BackSlot",
    [16] = "MainHandSlot",
    [17] = "SecondaryHandSlot",
    [18] = "RangedSlot",
    [19] = "TabardSlot"
}

-- Build a complete death record from cached killer data
function BloodPact_DataExtractor:BuildDeathRecord(killerName, killerLevel, killerType)
    local record = {}

    -- Identifiers
    record.characterName = UnitName("player") or "Unknown"
    record.accountID     = BloodPact_AccountIdentity:GetAccountID()

    -- Timestamps
    record.timestamp  = time()
    record.serverTime = date("%Y-%m-%d %H:%M:%S", record.timestamp)

    -- Character state
    record.level = UnitLevel("player") or 0
    record.totalXP = self:CalculateTotalXP(record.level)

    -- Race and class (English names at index 2)
    local _, raceEn  = UnitRace("player")
    local _, classEn = UnitClass("player")
    record.race  = raceEn  or "Unknown"
    record.class = classEn or "Unknown"

    -- Location
    record.zoneName    = GetZoneText() or "Unknown"
    record.subZoneName = GetSubZoneText() or ""

    -- Map coordinates - need to set map to current zone first
    SetMapToCurrentZone()
    local x, y = GetPlayerMapPosition("player")
    if x and y and x ~= 0 and y ~= 0 then
        record.mapX = x
        record.mapY = y
    end

    -- Killer information
    if killerName then
        record.killerName  = killerName
        record.killerLevel = killerLevel or 0
        record.killerType  = killerType or "NPC"
    else
        record.killerName = "Environment"
        record.killerType = "Environment"
    end

    -- Equipped rare+ items
    record.equippedItems = self:GetEquippedRareItems()

    -- Currency
    record.copperAmount = GetMoney() or 0

    -- Schema version
    record.version = BLOODPACT_SCHEMA_VERSION

    return record
end

-- Calculate approximate total XP using hardcoded level thresholds
function BloodPact_DataExtractor:CalculateTotalXP(level)
    if not level or level < 1 then return 0 end
    local baseXP = BLOODPACT_XP_PER_LEVEL[level] or 0
    local currentXP = UnitXP("player") or 0
    return baseXP + currentXP
end

-- Get all equipped items of rare (3) quality or higher
function BloodPact_DataExtractor:GetEquippedRareItems()
    local items = {}

    for slotID, slotName in pairs(SLOT_NAMES) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            -- Extract item ID from link format: |Hitem:ITEMID:...|h
            local itemIDStr = string.match(itemLink, "item:(%d+)")
            if itemIDStr then
                local itemID = tonumber(itemIDStr)
                -- GetItemInfo returns: name, link, quality, level, minLevel, type, subtype, ...
                local itemName, _, itemQuality = GetItemInfo(itemID)

                -- Only record rare (3) or higher quality
                if itemQuality and itemQuality >= 3 and itemName then
                    table.insert(items, {
                        itemName    = itemName,
                        itemID      = itemID,
                        itemQuality = itemQuality,
                        slot        = slotName
                    })
                end
            end
        end
    end

    return items
end
