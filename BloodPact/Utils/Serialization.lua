-- Blood Pact - Serialization
-- Fixed-field message serialization for addon communication
-- Uses pipe-delimited format: TYPE|field1|field2|...
-- Special characters in strings are escaped: | -> \p, \ -> \b, newline -> \n

BloodPact_Serialization = {}

-- Escape a string value for use in pipe-delimited format
local function Escape(str)
    if str == nil then return "" end
    str = tostring(str)
    str = string.gsub(str, "\\", "\\b")  -- backslash first
    str = string.gsub(str, "|", "\\p")   -- pipe separator
    str = string.gsub(str, "\n", "\\n")  -- newlines
    return str
end

-- Unescape a string value
local function Unescape(str)
    if str == nil or str == "" then return nil end
    str = string.gsub(str, "\\n", "\n")
    str = string.gsub(str, "\\p", "|")
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
-- Format: DA|senderAccountID|pactCode|charName|level|timestamp|
--         zoneName|subZone|mapX|mapY|killerName|killerLevel|killerType|
--         copperAmount|race|class|totalXP|items
-- ============================================================

function BloodPact_Serialization:SerializeDeathAnnounce(senderID, pactCode, record)
    local parts = {
        "DA",
        Escape(senderID),
        Escape(pactCode),
        Escape(record.characterName),
        tostring(record.level or 0),
        tostring(record.timestamp or 0),
        Escape(record.zoneName or ""),
        Escape(record.subZoneName or ""),
        tostring(record.mapX or 0),
        tostring(record.mapY or 0),
        Escape(record.killerName or "Unknown"),
        tostring(record.killerLevel or 0),
        Escape(record.killerType or "Unknown"),
        tostring(record.copperAmount or 0),
        Escape(record.race or ""),
        Escape(record.class or ""),
        tostring(record.totalXP or 0),
        EncodeItems(record.equippedItems)
    }
    return table.concat(parts, "|")
end

function BloodPact_Serialization:DeserializeDeathAnnounce(str)
    -- Split on pipes
    local fields = {}
    local pos = 1
    local len = string.len(str)
    while pos <= len do
        local nextPipe = string.find(str, "|", pos, true)
        -- But skip escaped pipes (\\p was already unescaped? No - we split first, then unescape)
        -- Actually we need to split carefully. Since | in values was escaped to \p,
        -- all remaining | are real separators.
        local part
        if nextPipe then
            part = string.sub(str, pos, nextPipe - 1)
            pos = nextPipe + 1
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
    record.level         = tonumber(fields[5]) or 0
    record.timestamp     = tonumber(fields[6]) or 0
    record.serverTime    = date("%Y-%m-%d %H:%M:%S", record.timestamp)
    record.zoneName      = Unescape(fields[7])
    record.subZoneName   = Unescape(fields[8])
    record.mapX          = tonumber(fields[9]) or 0
    record.mapY          = tonumber(fields[10]) or 0
    record.killerName    = Unescape(fields[11])
    record.killerLevel   = tonumber(fields[12]) or 0
    record.killerType    = Unescape(fields[13])
    record.copperAmount  = tonumber(fields[14]) or 0
    record.race          = Unescape(fields[15])
    record.class         = Unescape(fields[16])
    record.totalXP       = tonumber(fields[17]) or 0
    record.equippedItems = DecodeItems(fields[18])
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
-- Format: JR|senderAccountID|pactCode|timestamp
-- ============================================================

function BloodPact_Serialization:SerializeJoinRequest(senderID, pactCode)
    return "JR|" .. Escape(senderID) .. "|" .. Escape(pactCode) .. "|" .. tostring(time())
end

function BloodPact_Serialization:DeserializeJoinRequest(str)
    local t, sender, pact, ts = string.match(str, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if t ~= "JR" then return nil, nil end
    return Unescape(sender), Unescape(pact)
end

-- ============================================================
-- Message Type: JOIN_RESPONSE
-- Format: JR2|ownerAccountID|pactCode|pactName|createdTimestamp|newMemberAccountID
-- ============================================================

function BloodPact_Serialization:SerializeJoinResponse(ownerID, pactCode, pactName, createdTimestamp, newMemberID)
    return "JR2|" .. Escape(ownerID) .. "|" .. Escape(pactCode) .. "|" ..
           Escape(pactName) .. "|" .. tostring(createdTimestamp) .. "|" .. Escape(newMemberID)
end

function BloodPact_Serialization:DeserializeJoinResponse(str)
    local t, owner, pact, name, ts, newMember = string.match(str, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
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
-- Format: OT|pactCode|oldOwnerID|newOwnerID|timestamp
-- ============================================================

function BloodPact_Serialization:SerializeOwnershipTransfer(pactCode, oldOwnerID, newOwnerID)
    return "OT|" .. Escape(pactCode) .. "|" .. Escape(oldOwnerID) .. "|" ..
           Escape(newOwnerID) .. "|" .. tostring(time())
end

function BloodPact_Serialization:DeserializeOwnershipTransfer(str)
    local t, pact, old, new, ts = string.match(str, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
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
-- Format: SR|senderAccountID|pactCode|timestamp
-- ============================================================

function BloodPact_Serialization:SerializeSyncRequest(senderID, pactCode)
    return "SR|" .. Escape(senderID) .. "|" .. Escape(pactCode) .. "|" .. tostring(time())
end

function BloodPact_Serialization:DeserializeSyncRequest(str)
    local t, sender, pact, ts = string.match(str, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if t ~= "SR" then return nil, nil end
    return Unescape(sender), Unescape(pact)
end

-- ============================================================
-- Message Type: CHUNK (for bulk data transfers)
-- Format: CK|senderAccountID|pactCode|msgID|chunkIdx|totalChunks|payload
-- ============================================================

function BloodPact_Serialization:SerializeChunk(senderID, pactCode, msgID, chunkIdx, totalChunks, payload)
    return "CK|" .. Escape(senderID) .. "|" .. Escape(pactCode) .. "|" ..
           tostring(msgID) .. "|" .. tostring(chunkIdx) .. "|" ..
           tostring(totalChunks) .. "|" .. tostring(payload)
end

function BloodPact_Serialization:DeserializeChunk(str)
    -- Split manually since payload may contain pipes
    local fields = {}
    local pos = 1
    local len = string.len(str)
    local fieldCount = 0
    while pos <= len and fieldCount < 6 do
        local nextPipe = string.find(str, "|", pos, true)
        local part
        if nextPipe then
            part = string.sub(str, pos, nextPipe - 1)
            pos = nextPipe + 1
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
-- Utility: Get message type from raw string
-- ============================================================

function BloodPact_Serialization:GetMessageType(str)
    if not str then return nil end
    local msgType = string.match(str, "^([^|]*)")
    return msgType
end
