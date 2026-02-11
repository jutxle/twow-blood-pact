-- Blood Pact - Serialization
-- Fixed-field message serialization for addon communication
-- Uses tilde-delimited format: TYPE~field1~field2~...
-- Special characters in strings are escaped: ~ -> \d, \ -> \b, newline -> \n
-- NOTE: We use ~ instead of | because WoW's chat system treats | as an
-- escape character for color codes, and Turtle WoW's Hooks.lua validates
-- addon messages for valid escape sequences.

BloodPact_Serialization = {}

-- Escape a string value for use in tilde-delimited format
local function Escape(str)
    if str == nil then return "" end
    str = tostring(str)
    str = string.gsub(str, "\\", "\\b")  -- backslash first
    str = string.gsub(str, "~", "\\d")   -- tilde delimiter
    str = string.gsub(str, "\n", "\\n")  -- newlines
    return str
end

-- Unescape a string value
local function Unescape(str)
    if str == nil or str == "" then return nil end
    str = string.gsub(str, "\\n", "\n")
    str = string.gsub(str, "\\d", "~")
    str = string.gsub(str, "\\b", "\\")
    return str
end

-- Encode a single equipped item: "name:id:quality:slot"
local function EncodeItem(item)
    return Escape(item.itemName) .. ":" ..
           tostring(item.itemID) .. ":" ..
           tostring(item.itemQuality) .. ":" ..
           Escape(item.slot)
end

-- Decode a single equipped item
local function DecodeItem(str)
    if not str or str == "" then return nil end
    local parts = {}
    -- Split on unescaped colons
    local pattern = "([^:]*):([^:]*):([^:]*):([^:]*)"
    local name, id, quality, slot = string.match(str, pattern)
    if not name then return nil end
    return {
        itemName    = Unescape(name),
        itemID      = tonumber(id),
        itemQuality = tonumber(quality),
        slot        = Unescape(slot)
    }
end

-- Encode items array as semicolon-separated string
local function EncodeItems(items)
    if not items or table.getn(items) == 0 then return "" end
    local parts = {}
    for i = 1, table.getn(items) do
        table.insert(parts, EncodeItem(items[i]))
    end
    return table.concat(parts, ";")
end

-- Decode items string back to array
local function DecodeItems(str)
    if not str or str == "" then return {} end
    local items = {}
    -- Split on semicolons
    local pos = 1
    local len = string.len(str)
    while pos <= len do
        local nextSep = string.find(str, ";", pos, true)
        local part
        if nextSep then
            part = string.sub(str, pos, nextSep - 1)
            pos = nextSep + 1
        else
            part = string.sub(str, pos)
            pos = len + 1
        end
        local item = DecodeItem(part)
        if item then
            table.insert(items, item)
        end
    end
    return items
end

-- ============================================================
-- Message Type: DEATH_ANNOUNCE
-- Format: DA~senderAccountID~pactCode~charName~charInstanceID~level~timestamp~
--         zoneName~subZone~mapX~mapY~killerName~killerLevel~killerType~killerAbility~
--         copperAmount~race~class~totalXP~items
-- ============================================================

function BloodPact_Serialization:SerializeDeathAnnounce(senderID, pactCode, record)
    local parts = {
        "DA",
        Escape(senderID),
        Escape(pactCode),
        Escape(record.characterName),
        Escape(record.characterInstanceID or ""),
        tostring(record.level or 0),
        tostring(record.timestamp or 0),
        Escape(record.zoneName or ""),
        Escape(record.subZoneName or ""),
        tostring(record.mapX or 0),
        tostring(record.mapY or 0),
        Escape(record.killerName or "Unknown"),
        tostring(record.killerLevel or 0),
        Escape(record.killerType or "Unknown"),
        Escape(record.killerAbility or ""),
        tostring(record.copperAmount or 0),
        Escape(record.race or ""),
        Escape(record.class or ""),
        tostring(record.totalXP or 0),
        EncodeItems(record.equippedItems)
    }
    return table.concat(parts, "~")
end

function BloodPact_Serialization:DeserializeDeathAnnounce(str)
    -- Split on tildes
    local fields = {}
    local pos = 1
    local len = string.len(str)
    while pos <= len do
        local nextSep = string.find(str, "~", pos, true)
        local part
        if nextSep then
            part = string.sub(str, pos, nextSep - 1)
            pos = nextSep + 1
        else
            part = string.sub(str, pos)
            pos = len + 1
        end
        table.insert(fields, part)
    end

    if table.getn(fields) < 18 then
        return nil, nil, nil
    end

    local msgType     = fields[1]
    if msgType ~= "DA" then return nil, nil, nil end

    local senderID    = Unescape(fields[2])
    local pactCode    = Unescape(fields[3])

    local record = {}
    record.characterName = Unescape(fields[4])
    -- characterInstanceID: new in v2 format (19 fields); old format (18) lacks it
    local levelIdx = 5
    if table.getn(fields) >= 19 then
        record.characterInstanceID = Unescape(fields[5])
        if record.characterInstanceID == "" then record.characterInstanceID = nil end
        levelIdx = 6
    else
        record.characterInstanceID = nil
    end
    record.level         = tonumber(fields[levelIdx]) or 0
    record.timestamp     = tonumber(fields[levelIdx + 1]) or 0
    record.serverTime    = date("%Y-%m-%d %H:%M:%S", record.timestamp)
    record.zoneName      = Unescape(fields[levelIdx + 2])
    record.subZoneName   = Unescape(fields[levelIdx + 3])
    record.mapX          = tonumber(fields[levelIdx + 4]) or 0
    record.mapY          = tonumber(fields[levelIdx + 5]) or 0
    record.killerName    = Unescape(fields[levelIdx + 6])
    record.killerLevel   = tonumber(fields[levelIdx + 7]) or 0
    record.killerType    = Unescape(fields[levelIdx + 8])
    -- killerAbility: new in v3 format (20+ fields)
    local copperIdx = levelIdx + 9
    if table.getn(fields) >= levelIdx + 14 then
        record.killerAbility = Unescape(fields[levelIdx + 9] or "")
        if record.killerAbility == "" then record.killerAbility = nil end
        copperIdx = levelIdx + 10
    else
        record.killerAbility = nil
    end
    record.copperAmount  = tonumber(fields[copperIdx]) or 0
    record.race          = Unescape(fields[copperIdx + 1])
    record.class         = Unescape(fields[copperIdx + 2])
    record.totalXP       = tonumber(fields[copperIdx + 3]) or 0
    record.equippedItems = DecodeItems(fields[copperIdx + 4] or "")
    record.version       = BLOODPACT_SCHEMA_VERSION
    record.accountID     = senderID

    -- Normalize zero coords to nil
    if record.mapX == 0 and record.mapY == 0 then
        record.mapX = nil
        record.mapY = nil
    end

    return senderID, pactCode, record
end

-- ============================================================
-- Message Type: JOIN_REQUEST
-- Format: JR~senderAccountID~pactCode~timestamp
-- ============================================================

function BloodPact_Serialization:SerializeJoinRequest(senderID, pactCode)
    return "JR~" .. Escape(senderID) .. "~" .. Escape(pactCode) .. "~" .. tostring(time())
end

function BloodPact_Serialization:DeserializeJoinRequest(str)
    local t, sender, pact, ts = string.match(str, "^([^~]*)~([^~]*)~([^~]*)~([^~]*)$")
    if t ~= "JR" then return nil, nil end
    return Unescape(sender), Unescape(pact)
end

-- ============================================================
-- Message Type: JOIN_RESPONSE
-- Format: JR2~ownerAccountID~pactCode~pactName~createdTimestamp~newMemberAccountID
-- ============================================================

function BloodPact_Serialization:SerializeJoinResponse(ownerID, pactCode, pactName, createdTimestamp, newMemberID)
    return "JR2~" .. Escape(ownerID) .. "~" .. Escape(pactCode) .. "~" ..
           Escape(pactName) .. "~" .. tostring(createdTimestamp) .. "~" .. Escape(newMemberID)
end

function BloodPact_Serialization:DeserializeJoinResponse(str)
    local t, owner, pact, name, ts, newMember = string.match(str, "^([^~]*)~([^~]*)~([^~]*)~([^~]*)~([^~]*)~([^~]*)$")
    if t ~= "JR2" then return nil end
    return {
        ownerAccountID   = Unescape(owner),
        pactCode         = Unescape(pact),
        pactName         = Unescape(name),
        createdTimestamp = tonumber(ts) or 0,
        newMemberID      = Unescape(newMember)
    }
end

-- ============================================================
-- Message Type: OWNERSHIP_TRANSFER
-- Format: OT~pactCode~oldOwnerID~newOwnerID~timestamp
-- ============================================================

function BloodPact_Serialization:SerializeOwnershipTransfer(pactCode, oldOwnerID, newOwnerID)
    return "OT~" .. Escape(pactCode) .. "~" .. Escape(oldOwnerID) .. "~" ..
           Escape(newOwnerID) .. "~" .. tostring(time())
end

function BloodPact_Serialization:DeserializeOwnershipTransfer(str)
    local t, pact, old, new, ts = string.match(str, "^([^~]*)~([^~]*)~([^~]*)~([^~]*)~([^~]*)$")
    if t ~= "OT" then return nil end
    return {
        pactCode     = Unescape(pact),
        oldOwnerID   = Unescape(old),
        newOwnerID   = Unescape(new),
        timestamp    = tonumber(ts) or 0
    }
end

-- ============================================================
-- Message Type: SYNC_REQUEST
-- Format: SR~senderAccountID~pactCode~timestamp
-- ============================================================

function BloodPact_Serialization:SerializeSyncRequest(senderID, pactCode)
    return "SR~" .. Escape(senderID) .. "~" .. Escape(pactCode) .. "~" .. tostring(time())
end

function BloodPact_Serialization:DeserializeSyncRequest(str)
    local t, sender, pact, ts = string.match(str, "^([^~]*)~([^~]*)~([^~]*)~([^~]*)$")
    if t ~= "SR" then return nil, nil end
    return Unescape(sender), Unescape(pact)
end

-- ============================================================
-- Message Type: CHUNK (for bulk data transfers)
-- Format: CK~senderAccountID~pactCode~msgID~chunkIdx~totalChunks~payload
-- ============================================================

function BloodPact_Serialization:SerializeChunk(senderID, pactCode, msgID, chunkIdx, totalChunks, payload)
    return "CK~" .. Escape(senderID) .. "~" .. Escape(pactCode) .. "~" ..
           tostring(msgID) .. "~" .. tostring(chunkIdx) .. "~" ..
           tostring(totalChunks) .. "~" .. tostring(payload)
end

function BloodPact_Serialization:DeserializeChunk(str)
    -- Split manually since payload may contain tildes
    local fields = {}
    local pos = 1
    local len = string.len(str)
    local fieldCount = 0
    while pos <= len and fieldCount < 6 do
        local nextSep = string.find(str, "~", pos, true)
        local part
        if nextSep then
            part = string.sub(str, pos, nextSep - 1)
            pos = nextSep + 1
        else
            part = string.sub(str, pos)
            pos = len + 1
        end
        table.insert(fields, part)
        fieldCount = fieldCount + 1
    end
    -- Remainder is payload
    local payload = string.sub(str, pos - (string.len(fields[6] or "") + 1))

    if fields[1] ~= "CK" then return nil end
    return {
        senderID    = Unescape(fields[2]),
        pactCode    = Unescape(fields[3]),
        msgID       = tonumber(fields[4]) or 0,
        chunkIdx    = tonumber(fields[5]) or 0,
        totalChunks = tonumber(fields[6]) or 0,
        payload     = fields[7] or string.sub(str, pos)
    }
end

-- ============================================================
-- Message Type: ROSTER_SNAPSHOT
-- Format: RS~senderID~pactCode~charName~class~level~copper~prof1~prof1Lvl~prof2~prof2Lvl~t1Name~t1Pts~t2Name~t2Pts~t3Name~t3Pts~timestamp
-- (talent fields optional for backward compatibility)
-- ============================================================

function BloodPact_Serialization:SerializeRosterSnapshot(senderID, pactCode, snapshot)
    if not snapshot then return nil end
    local tabs = snapshot.talentTabs or {}
    local t1, t2, t3 = tabs[1], tabs[2], tabs[3]
    local parts = {
        "RS",
        Escape(senderID),
        Escape(pactCode),
        Escape(snapshot.characterName or ""),
        Escape(snapshot.class or ""),
        tostring(snapshot.level or 0),
        tostring(snapshot.copper or 0),
        Escape(snapshot.profession1 or ""),
        tostring(snapshot.profession1Level or 0),
        Escape(snapshot.profession2 or ""),
        tostring(snapshot.profession2Level or 0),
        Escape((t1 and t1.name) or ""),
        tostring((t1 and t1.pointsSpent) or 0),
        Escape((t2 and t2.name) or ""),
        tostring((t2 and t2.pointsSpent) or 0),
        Escape((t3 and t3.name) or ""),
        tostring((t3 and t3.pointsSpent) or 0),
        tostring(snapshot.timestamp or 0)
    }
    return table.concat(parts, "~")
end

function BloodPact_Serialization:DeserializeRosterSnapshot(str)
    local fields = {}
    local pos = 1
    local len = string.len(str)
    while pos <= len do
        local nextSep = string.find(str, "~", pos, true)
        local part
        if nextSep then
            part = string.sub(str, pos, nextSep - 1)
            pos = nextSep + 1
        else
            part = string.sub(str, pos)
            pos = len + 1
        end
        table.insert(fields, part)
    end

    if table.getn(fields) < 12 then return nil end
    if fields[1] ~= "RS" then return nil end

    local talentTabs = {}
    if table.getn(fields) >= 18 then
        table.insert(talentTabs, { name = Unescape(fields[12]), pointsSpent = tonumber(fields[13]) or 0 })
        table.insert(talentTabs, { name = Unescape(fields[14]), pointsSpent = tonumber(fields[15]) or 0 })
        table.insert(talentTabs, { name = Unescape(fields[16]), pointsSpent = tonumber(fields[17]) or 0 })
    end
    local timestampIdx = (table.getn(fields) >= 18) and 18 or 12

    return {
        senderID    = Unescape(fields[2]),
        pactCode    = Unescape(fields[3]),
        characterName = Unescape(fields[4]),
        class       = Unescape(fields[5]),
        level       = tonumber(fields[6]) or 0,
        copper      = tonumber(fields[7]) or 0,
        profession1 = Unescape(fields[8]),
        profession1Level = tonumber(fields[9]) or 0,
        profession2 = Unescape(fields[10]),
        profession2Level = tonumber(fields[11]) or 0,
        talentTabs  = talentTabs,
        timestamp   = tonumber(fields[timestampIdx]) or 0
    }
end

-- ============================================================
-- Message Type: DUNGEON_COMPLETION (single, real-time)
-- Format: DC~senderID~pactCode~charName~dungeonID~timestamp
-- ============================================================

function BloodPact_Serialization:SerializeDungeonCompletion(senderID, pactCode, completion)
    local parts = {
        "DC",
        Escape(senderID),
        Escape(pactCode),
        Escape(completion.characterName or ""),
        Escape(completion.dungeonID or ""),
        tostring(completion.timestamp or 0),
    }
    return table.concat(parts, "~")
end

function BloodPact_Serialization:DeserializeDungeonCompletion(str)
    local fields = {}
    local pos = 1
    local len = string.len(str)
    while pos <= len do
        local nextSep = string.find(str, "~", pos, true)
        local part
        if nextSep then
            part = string.sub(str, pos, nextSep - 1)
            pos = nextSep + 1
        else
            part = string.sub(str, pos)
            pos = len + 1
        end
        table.insert(fields, part)
    end

    if table.getn(fields) < 6 then return nil end
    if fields[1] ~= "DC" then return nil end

    return {
        senderID      = Unescape(fields[2]),
        pactCode      = Unescape(fields[3]),
        characterName = Unescape(fields[4]),
        dungeonID     = Unescape(fields[5]),
        timestamp     = tonumber(fields[6]) or 0,
    }
end

-- ============================================================
-- Message Type: DUNGEON_BULK (full sync on login/join)
-- Format: DB~senderID~pactCode~dungeonID1=ts1,dungeonID2=ts2,...
-- ============================================================

function BloodPact_Serialization:SerializeDungeonBulk(senderID, pactCode, completions)
    -- completions = { [dungeonID] = timestamp, ... }
    local dungeonParts = {}
    for dungeonID, ts in pairs(completions) do
        table.insert(dungeonParts, Escape(dungeonID) .. "=" .. tostring(ts))
    end
    local payload = table.concat(dungeonParts, ",")
    return "DB~" .. Escape(senderID) .. "~" .. Escape(pactCode) .. "~" .. payload
end

function BloodPact_Serialization:DeserializeDungeonBulk(str)
    -- Split into header fields: DB~senderID~pactCode~payload
    local fields = {}
    local pos = 1
    local len = string.len(str)
    local fieldCount = 0
    while pos <= len and fieldCount < 3 do
        local nextSep = string.find(str, "~", pos, true)
        local part
        if nextSep then
            part = string.sub(str, pos, nextSep - 1)
            pos = nextSep + 1
        else
            part = string.sub(str, pos)
            pos = len + 1
        end
        table.insert(fields, part)
        fieldCount = fieldCount + 1
    end
    -- Remainder is the payload
    local payload = string.sub(str, pos)

    if table.getn(fields) < 3 then return nil end
    if fields[1] ~= "DB" then return nil end

    -- Parse payload: dungeonID1=ts1,dungeonID2=ts2,...
    local completions = {}
    if payload and string.len(payload) > 0 then
        local pPos = 1
        local pLen = string.len(payload)
        while pPos <= pLen do
            local nextComma = string.find(payload, ",", pPos, true)
            local entry
            if nextComma then
                entry = string.sub(payload, pPos, nextComma - 1)
                pPos = nextComma + 1
            else
                entry = string.sub(payload, pPos)
                pPos = pLen + 1
            end
            -- Parse "dungeonID=timestamp"
            local eqPos = string.find(entry, "=", 1, true)
            if eqPos then
                local dungeonID = Unescape(string.sub(entry, 1, eqPos - 1))
                local ts = tonumber(string.sub(entry, eqPos + 1)) or 0
                if dungeonID and string.len(dungeonID) > 0 then
                    completions[dungeonID] = ts
                end
            end
        end
    end

    return {
        senderID    = Unescape(fields[2]),
        pactCode    = Unescape(fields[3]),
        completions = completions,
    }
end

-- ============================================================
-- Utility: Get message type from raw string
-- ============================================================

function BloodPact_Serialization:GetMessageType(str)
    if not str then return nil end
    local msgType = string.match(str, "^([^~]*)")
    return msgType
end
