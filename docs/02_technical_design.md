# Blood Pact - Technical Design Document
**Version:** 1.0  
**Date:** February 7, 2026  
**Author:** Justin  
**Target Platform:** Turtle WoW (WoW 1.12 Client, Lua 5.1)

---

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Data Structures](#data-structures)
3. [Combat Log Parsing Engine](#combat-log-parsing-engine)
4. [Account Identity System](#account-identity-system)
5. [Blood Pact Synchronization Protocol](#blood-pact-synchronization-protocol)
6. [SavedVariables Schema](#savedvariables-schema)
7. [API Definitions](#api-definitions)
8. [Error Handling Strategy](#error-handling-strategy)
9. [Performance Optimization](#performance-optimization)
10. [WoW 1.12 API Constraints](#wow-112-api-constraints)

---

## System Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Blood Pact Addon                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────┐      ┌──────────────────────────┐   │
│  │   Combat Log      │      │   Death Data Manager     │   │
│  │   Parser          │─────>│   - Storage              │   │
│  │   - Event Hook    │      │   - Validation           │   │
│  │   - State Machine │      │   - Pruning (25 limit)   │   │
│  └───────────────────┘      └──────────────────────────┘   │
│           │                              │                   │
│           │                              │                   │
│  ┌────────▼──────────┐      ┌───────────▼──────────────┐   │
│  │   Character       │      │   SavedVariables         │   │
│  │   Validator       │      │   Handler                │   │
│  │   - Title Check   │      │   - Load/Save            │   │
│  │   - Hardcore Only │      │   - Corruption Check     │   │
│  └───────────────────┘      └──────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Pact Synchronization Engine             │   │
│  │   - Message Serialization                            │   │
│  │   - Addon Communication (SendAddonMessage)           │   │
│  │   - Conflict Resolution                              │   │
│  │   - Rate Limiting                                    │   │
│  └──────────────────────────────────────────────────────┘   │
│           │                              │                   │
│           │                              │                   │
│  ┌────────▼──────────┐      ┌───────────▼──────────────┐   │
│  │   Join Code       │      │   Ownership Manager      │   │
│  │   Generator       │      │   - Transfer Logic       │   │
│  │   - Collision     │      │   - Dormancy Handling    │   │
│  │     Resistance    │      └──────────────────────────┘   │
│  └───────────────────┘                                      │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    UI Layer (PFUI-styled)            │   │
│  │   - Personal Dashboard                               │   │
│  │   - Personal Timeline                                │   │
│  │   - Pact Dashboard                                   │   │
│  │   - Pact Timeline                                    │   │
│  │   - Settings Panel                                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Command Handler (/bloodpact)            │   │
│  │   - show, toggle, join, export, wipe, help           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
BloodPact/
├── BloodPact.toc              # Addon metadata
├── Core.lua                   # Initialization, event registration
├── Config.lua                 # Constants, configuration values
├── Data/
│   ├── DeathDataManager.lua   # Death record CRUD operations
│   ├── AccountIdentity.lua    # Account ID generation/retrieval
│   └── SavedVariablesHandler.lua # SavedVariables I/O, validation
├── CombatLog/
│   ├── Parser.lua             # Combat log event processing
│   ├── DeathDetector.lua      # Multi-signal death detection
│   └── DataExtractor.lua      # Inventory, location, killer extraction
├── Pact/
│   ├── PactManager.lua        # Pact creation, joining, roster
│   ├── JoinCodeGenerator.lua  # Random code generation
│   ├── SyncEngine.lua         # Addon communication, serialization
│   ├── ConflictResolver.lua   # Timestamp-based conflict handling
│   └── OwnershipManager.lua   # Ownership transfer logic
├── UI/
│   ├── MainFrame.lua          # Primary UI window frame
│   ├── PersonalDashboard.lua  # Individual stats panel
│   ├── PersonalTimeline.lua   # Individual timeline renderer
│   ├── PactDashboard.lua      # Pact stats panel
│   ├── PactTimeline.lua       # Pact timeline renderer
│   └── PFUIStyles.lua         # PFUI color/font/texture helpers
├── Commands/
│   ├── CommandHandler.lua     # Slash command routing
│   └── ExportHandler.lua      # JSON export logic
└── Utils/
    ├── Logger.lua             # Debug/error logging
    ├── Serialization.lua      # Table to string conversion
    └── RateLimiter.lua        # Message throttling
```

---

## Data Structures

### Death Record Schema

```lua
-- Single death record structure
DeathRecord = {
    -- Identifiers
    characterName = "MyHardcoreWarrior",  -- string
    accountID = "MyFirstCharacter",       -- string (account identifier)
    
    -- Death Metadata
    timestamp = 1234567890,               -- number (Unix timestamp from time())
    serverTime = "2026-02-07 15:34:22",   -- string (formatted date/time)
    
    -- Character State
    level = 42,                           -- number (1-60)
    totalXP = 485000,                     -- number
    race = "Orc",                         -- string
    class = "Warrior",                    -- string
    
    -- Location
    zoneName = "Tanaris",                 -- string
    subZoneName = "Gadgetzan",            -- string (may be nil)
    mapX = 0.513,                         -- number (0.0-1.0, may be nil)
    mapY = 0.287,                         -- number (0.0-1.0, may be nil)
    
    -- Killer Information
    killerName = "Wastewander Rogue",     -- string
    killerLevel = 44,                     -- number (may be nil for environment)
    killerType = "NPC",                   -- string: "NPC", "Environment", "Unknown"
    
    -- Inventory Snapshot (rare+ equipped items only)
    equippedItems = {
        {
            itemName = "Verigan's Fist",
            itemID = 6953,
            itemQuality = 3,              -- number: 3=rare, 4=epic, 5=legendary
            slot = "MainHandSlot"
        },
        -- ... more items
    },
    
    -- Currency
    copperAmount = 124573,                -- number (total copper, convert to g/s/c for display)
    
    -- Integrity
    version = 1                           -- number (schema version for future migrations)
}
```

### Account Data Schema

```lua
-- Per-account data (stored in SavedVariablesPerCharacter)
BloodPactAccountDB = {
    -- Account Identity
    accountID = "MyFirstCharacter",       -- string (never changes)
    accountCreatedTimestamp = 1234567890, -- number
    
    -- Death History (keyed by character name)
    deaths = {
        ["MyHardcoreWarrior"] = {
            -- Array of DeathRecords (max 25)
            [1] = { --[[ DeathRecord ]] },
            [2] = { --[[ DeathRecord ]] },
            -- ...
        },
        ["AnotherHardcoreChar"] = {
            -- ...
        }
    },
    
    -- Pact Membership (nil if not in a pact)
    pact = {
        pactName = "The Fallen Legion",
        joinCode = "A7K9M2X5",
        ownerAccountID = "SomeOtherPlayer",
        joinedTimestamp = 1234567890,
        
        -- Local cache of pact member data
        members = {
            ["PlayerOne"] = {
                accountID = "PlayerOne",
                highestLevel = 58,
                deathCount = 12,
                isAlive = true,           -- bool: does this player have any living chars?
                joinedTimestamp = 1234567800
            },
            -- ... more members
        },
        
        -- Synchronized death data from other members
        syncedDeaths = {
            ["PlayerOne"] = {
                ["TheirCharName"] = {
                    -- Array of DeathRecords from other players
                    [1] = { --[[ DeathRecord ]] },
                    -- ...
                }
            }
        }
    },
    
    -- Configuration
    config = {
        uiScale = 1.0,
        showTimeline = true,
        -- ... future config options
    },
    
    -- Metadata
    version = 1                           -- number (schema version)
}
```

### Pact Creation Data

```lua
-- Data structure for creating a new pact
PactCreationData = {
    pactName = "The Fallen Legion",      -- string (1-32 chars)
    joinCode = "A7K9M2X5",               -- string (8 chars, alphanumeric)
    ownerAccountID = "MyFirstCharacter", -- string
    createdTimestamp = 1234567890,       -- number
    version = 1                          -- number
}
```

### Sync Message Schemas

```lua
-- Message Type 1: Death Announcement
DeathAnnouncementMessage = {
    msgType = "DEATH_ANNOUNCE",
    senderAccountID = "MyFirstCharacter",
    pactJoinCode = "A7K9M2X5",
    deathRecord = { --[[ Full DeathRecord ]] },
    timestamp = 1234567890
}

-- Message Type 2: Join Request
JoinRequestMessage = {
    msgType = "JOIN_REQUEST",
    senderAccountID = "NewPlayer",
    pactJoinCode = "A7K9M2X5",
    timestamp = 1234567890
}

-- Message Type 3: Join Response (sent by pact owner to all members)
JoinResponseMessage = {
    msgType = "JOIN_RESPONSE",
    senderAccountID = "PactOwner",
    pactJoinCode = "A7K9M2X5",
    newMemberAccountID = "NewPlayer",
    pactData = { --[[ PactCreationData ]] },
    timestamp = 1234567890
}

-- Message Type 4: Bulk Data Sync (chunked for large datasets)
BulkDataSyncMessage = {
    msgType = "BULK_SYNC",
    senderAccountID = "MyFirstCharacter",
    pactJoinCode = "A7K9M2X5",
    chunkIndex = 1,
    totalChunks = 5,
    data = { --[[ Partial death data ]] },
    timestamp = 1234567890
}

-- Message Type 5: Ownership Transfer Notification
OwnershipTransferMessage = {
    msgType = "OWNERSHIP_TRANSFER",
    pactJoinCode = "A7K9M2X5",
    oldOwnerAccountID = "FormerOwner",
    newOwnerAccountID = "NewOwner",
    timestamp = 1234567890
}
```

---

## Combat Log Parsing Engine

### Event Registration (WoW 1.12)

```lua
-- Core.lua initialization
local BloodPactFrame = CreateFrame("Frame")

function BloodPact_OnLoad()
    -- Register for combat log events
    BloodPactFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    BloodPactFrame:RegisterEvent("PLAYER_DEAD")
    BloodPactFrame:RegisterEvent("PLAYER_UNGHOST")
    BloodPactFrame:RegisterEvent("PLAYER_ALIVE")
    
    -- Register for addon communication
    BloodPactFrame:RegisterEvent("CHAT_MSG_ADDON")
    
    -- Register for SavedVariables
    BloodPactFrame:RegisterEvent("VARIABLES_LOADED")
    BloodPactFrame:RegisterEvent("PLAYER_LOGOUT")
    
    -- Set script handler
    BloodPactFrame:SetScript("OnEvent", BloodPact_OnEvent)
end
```

### Death Detection State Machine

```lua
-- CombatLog/DeathDetector.lua

BloodPact_DeathDetector = {
    -- State tracking for death detection
    suspectedDeath = false,
    deathTimestamp = nil,
    deathConfirmed = false,
    
    -- Cached data during death sequence
    pendingDeathData = {}
}

function BloodPact_DeathDetector:OnCombatLogEvent(event, arg1, arg2, ...)
    if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        -- UNIT_DIED equivalent in 1.12 combat log
        -- Parse message like "Wastewander Rogue dies."
        
        if self:IsPlayerDeath(arg1) then
            self.suspectedDeath = true
            self.deathTimestamp = time()
            
            -- Extract data from combat log
            self:ExtractDeathContext(arg1)
        end
    end
end

function BloodPact_DeathDetector:OnPlayerDead()
    -- PLAYER_DEAD event fired
    if self.suspectedDeath then
        -- Confirm death (cross-reference with combat log signal)
        self.deathConfirmed = true
        self:ConfirmAndLogDeath()
    else
        -- PLAYER_DEAD without prior combat log signal
        -- Possible environmental death (fall, drown, fatigue)
        self.suspectedDeath = true
        self.deathConfirmed = true
        self:ExtractDeathContext(nil) -- No killer entity
        self:ConfirmAndLogDeath()
    end
end

function BloodPact_DeathDetector:ConfirmAndLogDeath()
    -- Double-check hardcore status
    if not self:IsHardcoreCharacter() then
        self:Reset()
        return
    end
    
    -- Build complete death record
    local deathRecord = BloodPact_DataExtractor:BuildDeathRecord(
        self.pendingDeathData
    )
    
    -- Save to SavedVariables
    BloodPact_DeathDataManager:RecordDeath(deathRecord)
    
    -- Broadcast to pact if applicable
    if BloodPact_PactManager:IsInPact() then
        BloodPact_SyncEngine:BroadcastDeath(deathRecord)
    end
    
    -- Reset state
    self:Reset()
end

function BloodPact_DeathDetector:IsHardcoreCharacter()
    -- Check for "Still Alive" title in player's title list
    -- WoW 1.12 API: GetNumTitles(), GetTitleName(index)
    
    local numTitles = GetNumTitles()
    for i = 1, numTitles do
        local titleName = GetTitleName(i)
        if titleName and string.find(titleName, "Still Alive") then
            return true
        end
    end
    
    return false
end

function BloodPact_DeathDetector:Reset()
    self.suspectedDeath = false
    self.deathTimestamp = nil
    self.deathConfirmed = false
    self.pendingDeathData = {}
end
```

### Data Extraction Logic

```lua
-- CombatLog/DataExtractor.lua

BloodPact_DataExtractor = {}

function BloodPact_DataExtractor:BuildDeathRecord(cachedData)
    local record = {}
    
    -- Character identification
    record.characterName = UnitName("player")
    record.accountID = BloodPact_AccountIdentity:GetAccountID()
    
    -- Timestamp
    record.timestamp = time()
    record.serverTime = date("%Y-%m-%d %H:%M:%S", record.timestamp)
    
    -- Character state
    record.level = UnitLevel("player")
    record.totalXP = UnitXP("player") + UnitXPMax("player") * (record.level - 1)
    
    local _, raceEn = UnitRace("player")
    local _, classEn = UnitClass("player")
    record.race = raceEn
    record.class = classEn
    
    -- Location
    record.zoneName = GetZoneText()
    record.subZoneName = GetSubZoneText()
    
    -- Map coordinates (may be nil if unavailable)
    local x, y = GetPlayerMapPosition("player")
    if x ~= 0 and y ~= 0 then
        record.mapX = x
        record.mapY = y
    end
    
    -- Killer information (from cached combat log data)
    if cachedData.killerName then
        record.killerName = cachedData.killerName
        record.killerLevel = cachedData.killerLevel
        record.killerType = cachedData.killerType or "NPC"
    else
        -- Environmental death
        record.killerName = "Environment"
        record.killerType = "Environment"
    end
    
    -- Equipped items (rare+ only)
    record.equippedItems = self:GetEquippedRareItems()
    
    -- Currency
    record.copperAmount = GetMoney()
    
    -- Schema version
    record.version = 1
    
    return record
end

function BloodPact_DataExtractor:GetEquippedRareItems()
    local items = {}
    
    -- Iterate through all equipment slots
    -- WoW 1.12 slot IDs: 1-19 (some gaps)
    local slotNames = {
        [1] = "HeadSlot",
        [2] = "NeckSlot",
        [3] = "ShoulderSlot",
        [5] = "ChestSlot",
        [6] = "WaistSlot",
        [7] = "LegsSlot",
        [8] = "FeetSlot",
        [9] = "WristSlot",
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
    
    for slotID, slotName in pairs(slotNames) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            -- Parse item link to extract item ID and quality
            local _, _, itemID = string.find(itemLink, "item:(%d+)")
            if itemID then
                local _, _, itemQuality = GetItemInfo(itemID)
                
                -- Only record rare (3) or higher
                if itemQuality and itemQuality >= 3 then
                    local itemName = GetItemInfo(itemID)
                    table.insert(items, {
                        itemName = itemName,
                        itemID = tonumber(itemID),
                        itemQuality = itemQuality,
                        slot = slotName
                    })
                end
            end
        end
    end
    
    return items
end
```

### Combat Log Parsing Throttling

```lua
-- Prevent FPS drops from excessive event processing
local COMBAT_LOG_THROTTLE_INTERVAL = 0.1  -- Process max once per 100ms

local lastProcessTime = 0

function BloodPact_OnCombatLogEvent(event, ...)
    local currentTime = GetTime()
    
    if currentTime - lastProcessTime < COMBAT_LOG_THROTTLE_INTERVAL then
        -- Skip processing, too soon since last event
        return
    end
    
    lastProcessTime = currentTime
    
    -- Process event
    BloodPact_DeathDetector:OnCombatLogEvent(event, ...)
end
```

---

## Account Identity System

### Account ID Generation

```lua
-- Data/AccountIdentity.lua

BloodPact_AccountIdentity = {}

function BloodPact_AccountIdentity:Initialize()
    -- Check if account ID already exists
    if BloodPactAccountDB and BloodPactAccountDB.accountID then
        -- Already initialized
        return
    end
    
    -- First launch: generate account ID from character name
    local characterName = UnitName("player")
    
    -- Initialize database structure
    if not BloodPactAccountDB then
        BloodPactAccountDB = {}
    end
    
    BloodPactAccountDB.accountID = characterName
    BloodPactAccountDB.accountCreatedTimestamp = time()
    BloodPactAccountDB.deaths = {}
    BloodPactAccountDB.pact = nil
    BloodPactAccountDB.config = {
        uiScale = 1.0,
        showTimeline = true
    }
    BloodPactAccountDB.version = 1
    
    -- Log to chat
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cFFFF6600[Blood Pact]|r Account initialized. Your account ID is: " .. 
        characterName
    )
end

function BloodPact_AccountIdentity:GetAccountID()
    if BloodPactAccountDB and BloodPactAccountDB.accountID then
        return BloodPactAccountDB.accountID
    end
    return nil
end
```

---

## Blood Pact Synchronization Protocol

### Join Code Generation

```lua
-- Pact/JoinCodeGenerator.lua

BloodPact_JoinCodeGenerator = {}

function BloodPact_JoinCodeGenerator:GenerateCode()
    -- Generate 8-character alphanumeric code (case-insensitive)
    -- Character set: A-Z, 0-9 (36 possible characters)
    -- Total combinations: 36^8 = 2,821,109,907,456 (2.8 trillion)
    -- Collision probability with 10,000 codes: ~0.0000035%
    
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local code = ""
    
    for i = 1, 8 do
        local randIndex = math.random(1, string.len(chars))
        code = code .. string.sub(chars, randIndex, randIndex)
    end
    
    return code
end

function BloodPact_JoinCodeGenerator:ValidateCodeFormat(code)
    -- Check format: 8 alphanumeric characters
    if type(code) ~= "string" then
        return false
    end
    
    if string.len(code) ~= 8 then
        return false
    end
    
    -- Check each character is alphanumeric
    for i = 1, 8 do
        local char = string.sub(code, i, i)
        if not string.find(char, "[A-Za-z0-9]") then
            return false
        end
    end
    
    return true
end
```

### Addon Communication Protocol

```lua
-- Pact/SyncEngine.lua

BloodPact_SyncEngine = {
    MESSAGE_PREFIX = "BLOODPACT",
    CHANNEL = "GUILD", -- Use GUILD channel for pact comms (alternative: RAID, PARTY)
    
    -- Rate limiting (WoW 1.12 throttles addon messages)
    messageQueue = {},
    lastSendTime = 0,
    MIN_MESSAGE_INTERVAL = 0.5  -- 500ms between messages
}

function BloodPact_SyncEngine:Initialize()
    -- Register addon message prefix
    -- WoW 1.12: RegisterAddonMessagePrefix (if available, may not exist in 1.12)
    -- Fallback: Messages will still work, just not filtered by prefix
    
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(self.MESSAGE_PREFIX)
    end
end

function BloodPact_SyncEngine:BroadcastDeath(deathRecord)
    local message = {
        msgType = "DEATH_ANNOUNCE",
        senderAccountID = BloodPact_AccountIdentity:GetAccountID(),
        pactJoinCode = BloodPactAccountDB.pact.joinCode,
        deathRecord = deathRecord,
        timestamp = time()
    }
    
    self:QueueMessage(message)
end

function BloodPact_SyncEngine:QueueMessage(message)
    table.insert(self.messageQueue, message)
    
    -- Attempt to flush queue
    self:FlushMessageQueue()
end

function BloodPact_SyncEngine:FlushMessageQueue()
    if table.getn(self.messageQueue) == 0 then
        return
    end
    
    local currentTime = GetTime()
    if currentTime - self.lastSendTime < self.MIN_MESSAGE_INTERVAL then
        -- Too soon, try again later
        return
    end
    
    -- Send next message in queue
    local message = table.remove(self.messageQueue, 1)
    local serialized = BloodPact_Serialization:Serialize(message)
    
    -- WoW 1.12 message size limit: 255 bytes
    if string.len(serialized) > 255 then
        -- Message too large, chunk it
        self:SendChunkedMessage(message)
    else
        SendAddonMessage(self.MESSAGE_PREFIX, serialized, self.CHANNEL)
        self.lastSendTime = currentTime
    end
    
    -- Schedule next flush if queue not empty
    if table.getn(self.messageQueue) > 0 then
        -- Use a timer to retry (WoW 1.12 doesn't have C_Timer)
        -- Implement via OnUpdate handler
        BloodPact_SyncEngine.needsFlush = true
    end
end

function BloodPact_SyncEngine:SendChunkedMessage(message)
    -- Split large message into chunks of 200 bytes (safe margin)
    local serialized = BloodPact_Serialization:Serialize(message)
    local chunkSize = 200
    local totalChunks = math.ceil(string.len(serialized) / chunkSize)
    
    for i = 1, totalChunks do
        local startIdx = (i - 1) * chunkSize + 1
        local endIdx = math.min(i * chunkSize, string.len(serialized))
        local chunk = string.sub(serialized, startIdx, endIdx)
        
        local chunkMessage = {
            msgType = "BULK_SYNC",
            senderAccountID = BloodPact_AccountIdentity:GetAccountID(),
            pactJoinCode = BloodPactAccountDB.pact.joinCode,
            chunkIndex = i,
            totalChunks = totalChunks,
            data = chunk,
            timestamp = time()
        }
        
        self:QueueMessage(chunkMessage)
    end
end

function BloodPact_SyncEngine:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.MESSAGE_PREFIX then
        return
    end
    
    -- Deserialize message
    local data = BloodPact_Serialization:Deserialize(message)
    if not data then
        -- Invalid message format
        return
    end
    
    -- Verify message is for our pact
    if not BloodPactAccountDB.pact then
        return -- Not in a pact
    end
    
    if data.pactJoinCode ~= BloodPactAccountDB.pact.joinCode then
        return -- Message for different pact
    end
    
    -- Route message by type
    if data.msgType == "DEATH_ANNOUNCE" then
        BloodPact_PactManager:OnPactMemberDeath(data)
    elseif data.msgType == "JOIN_REQUEST" then
        BloodPact_PactManager:OnJoinRequest(data, sender)
    elseif data.msgType == "JOIN_RESPONSE" then
        BloodPact_PactManager:OnJoinResponse(data)
    elseif data.msgType == "BULK_SYNC" then
        BloodPact_PactManager:OnBulkSync(data)
    elseif data.msgType == "OWNERSHIP_TRANSFER" then
        BloodPact_PactManager:OnOwnershipTransfer(data)
    end
end

-- OnUpdate handler for message queue flushing
function BloodPact_SyncEngine:OnUpdate()
    if self.needsFlush then
        self:FlushMessageQueue()
        
        if table.getn(self.messageQueue) == 0 then
            self.needsFlush = false
        end
    end
end
```

### Conflict Resolution

```lua
-- Pact/ConflictResolver.lua

BloodPact_ConflictResolver = {}

function BloodPact_ConflictResolver:ResolveDeathConflict(localRecord, remoteRecord)
    -- Use timestamp as tie-breaker
    -- Earlier timestamp wins (death occurred first)
    
    if localRecord.timestamp < remoteRecord.timestamp then
        return localRecord
    elseif remoteRecord.timestamp < localRecord.timestamp then
        return remoteRecord
    else
        -- Exact same timestamp (unlikely but possible)
        -- Use character name alphabetically as final tie-breaker
        if localRecord.characterName < remoteRecord.characterName then
            return localRecord
        else
            return remoteRecord
        end
    end
end

function BloodPact_ConflictResolver:MergeDeathHistories(local Deaths, remoteDeaths)
    -- Merge two death history tables, resolving conflicts
    local merged = {}
    
    -- Copy local deaths
    for charName, deathList in pairs(localDeaths) do
        merged[charName] = {}
        for _, death in ipairs(deathList) do
            table.insert(merged[charName], death)
        end
    end
    
    -- Merge remote deaths
    for charName, deathList in pairs(remoteDeaths) do
        if not merged[charName] then
            merged[charName] = {}
        end
        
        for _, remoteDeath in ipairs(deathList) do
            -- Check if this death already exists locally
            local exists = false
            for _, localDeath in ipairs(merged[charName]) do
                if self:IsSameDeath(localDeath, remoteDeath) then
                    -- Conflict: same death reported differently
                    local resolved = self:ResolveDeathConflict(localDeath, remoteDeath)
                    
                    -- Replace local death with resolved version
                    for i, d in ipairs(merged[charName]) do
                        if self:IsSameDeath(d, localDeath) then
                            merged[charName][i] = resolved
                            break
                        end
                    end
                    
                    exists = true
                    break
                end
            end
            
            if not exists then
                -- New death, add it
                table.insert(merged[charName], remoteDeath)
            end
        end
        
        -- Sort deaths by timestamp (most recent first)
        table.sort(merged[charName], function(a, b)
            return a.timestamp > b.timestamp
        end)
        
        -- Enforce 25-death limit per character
        while table.getn(merged[charName]) > 25 do
            table.remove(merged[charName]) -- Remove oldest (last in sorted array)
        end
    end
    
    return merged
end

function BloodPact_ConflictResolver:IsSameDeath(death1, death2)
    -- Two deaths are considered "same" if:
    -- - Same character name
    -- - Timestamps within 10 seconds of each other
    -- - Same level
    
    if death1.characterName ~= death2.characterName then
        return false
    end
    
    if math.abs(death1.timestamp - death2.timestamp) > 10 then
        return false
    end
    
    if death1.level ~= death2.level then
        return false
    end
    
    return true
end
```

---

## SavedVariables Schema

### File Location
```
WTF/Account/<AccountName>/SavedVariables/BloodPact.lua
```

### SavedVariables Declaration (BloodPact.toc)

```toc
## SavedVariablesPerCharacter: BloodPactAccountDB
```

### SavedVariables Handler

```lua
-- Data/SavedVariablesHandler.lua

BloodPact_SavedVariablesHandler = {}

function BloodPact_SavedVariablesHandler:OnVariablesLoaded()
    -- Variables loaded event fired
    
    -- Initialize account identity
    BloodPact_AccountIdentity:Initialize()
    
    -- Validate data integrity
    self:ValidateData()
    
    -- Migrate schema if needed
    self:MigrateSchema()
end

function BloodPact_SavedVariablesHandler:ValidateData()
    if not BloodPactAccountDB then
        return -- Nothing to validate
    end
    
    -- Check version field
    if not BloodPactAccountDB.version then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFFFF0000[Blood Pact] ERROR:|r SavedVariables missing version field. Data may be corrupted."
        )
        return
    end
    
    -- Validate deaths table structure
    if BloodPactAccountDB.deaths then
        for charName, deathList in pairs(BloodPactAccountDB.deaths) do
            if type(deathList) ~= "table" then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cFFFF0000[Blood Pact] ERROR:|r Corrupted death data for character: " .. charName
                )
                BloodPactAccountDB.deaths[charName] = {}
            end
        end
    end
    
    -- Validate pact structure
    if BloodPactAccountDB.pact then
        if not BloodPactAccountDB.pact.joinCode or not BloodPactAccountDB.pact.pactName then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cFFFF0000[Blood Pact] ERROR:|r Corrupted pact data. Pact membership reset."
            )
            BloodPactAccountDB.pact = nil
        end
    end
end

function BloodPact_SavedVariablesHandler:MigrateSchema()
    if not BloodPactAccountDB then
        return
    end
    
    local currentVersion = BloodPactAccountDB.version or 1
    
    -- Future schema migrations will go here
    -- Example:
    -- if currentVersion < 2 then
    --     self:MigrateV1ToV2()
    --     BloodPactAccountDB.version = 2
    -- end
end

function BloodPact_SavedVariablesHandler:OnPlayerLogout()
    -- SavedVariables automatically written on logout
    -- Optional: Perform any cleanup or final validation here
end
```

---

## API Definitions

### Public API for Other Addons

```lua
-- BloodPact Public API
-- Other addons can call these functions to interact with Blood Pact

BloodPactAPI = {
    version = "1.0.0"
}

-- Get total death count for current account
-- Returns: number
function BloodPactAPI:GetTotalDeaths()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return 0
    end
    
    local total = 0
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        total = total + table.getn(deathList)
    end
    
    return total
end

-- Get highest level achieved across all characters
-- Returns: number (1-60)
function BloodPactAPI:GetHighestLevel()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return 1
    end
    
    local highest = 1
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        for _, death in ipairs(deathList) do
            if death.level > highest then
                highest = death.level
            end
        end
    end
    
    return highest
end

-- Get total gold lost
-- Returns: number (in gold, not copper)
function BloodPactAPI:GetTotalGoldLost()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return 0
    end
    
    local totalCopper = 0
    for _, deathList in pairs(BloodPactAccountDB.deaths) do
        for _, death in ipairs(deathList) do
            totalCopper = totalCopper + (death.copperAmount or 0)
        end
    end
    
    return totalCopper / 10000 -- Convert copper to gold
end

-- Check if current character is hardcore
-- Returns: boolean
function BloodPactAPI:IsHardcoreCharacter()
    return BloodPact_DeathDetector:IsHardcoreCharacter()
end

-- Get account ID
-- Returns: string or nil
function BloodPactAPI:GetAccountID()
    return BloodPact_AccountIdentity:GetAccountID()
end

-- Check if in a pact
-- Returns: boolean
function BloodPactAPI:IsInPact()
    return BloodPactAccountDB and BloodPactAccountDB.pact ~= nil
end

-- Get pact information
-- Returns: table {pactName, joinCode, memberCount} or nil
function BloodPactAPI:GetPactInfo()
    if not self:IsInPact() then
        return nil
    end
    
    local memberCount = 0
    if BloodPactAccountDB.pact.members then
        for _ in pairs(BloodPactAccountDB.pact.members) do
            memberCount = memberCount + 1
        end
    end
    
    return {
        pactName = BloodPactAccountDB.pact.pactName,
        joinCode = BloodPactAccountDB.pact.joinCode,
        memberCount = memberCount
    }
end
```

---

## Error Handling Strategy

### Error Categories

1. **Critical Errors** - Addon cannot function, user notified
2. **Warning Errors** - Feature degraded, addon continues
3. **Info Logs** - Debug information (not shown to user by default)

### Error Handling Implementation

```lua
-- Utils/Logger.lua

BloodPact_Logger = {
    LOG_LEVEL = {
        INFO = 1,
        WARNING = 2,
        ERROR = 3
    },
    
    currentLevel = 2 -- Default: show warnings and errors only
}

function BloodPact_Logger:SetLogLevel(level)
    self.currentLevel = level
end

function BloodPact_Logger:Info(message)
    if self.currentLevel <= self.LOG_LEVEL.INFO then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFF00FF00[Blood Pact INFO]|r " .. message
        )
    end
end

function BloodPact_Logger:Warning(message)
    if self.currentLevel <= self.LOG_LEVEL.WARNING then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFFFFAA00[Blood Pact WARNING]|r " .. message
        )
    end
end

function BloodPact_Logger:Error(message)
    if self.currentLevel <= self.LOG_LEVEL.ERROR then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFFFF0000[Blood Pact ERROR]|r " .. message
        )
    end
end

function BloodPact_Logger:Critical(message)
    -- Always show critical errors
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cFFFF0000[Blood Pact CRITICAL]|r " .. message
    )
    
    -- Show error dialog
    StaticPopup_Show("BLOODPACT_CRITICAL_ERROR", message)
end
```

### Static Popup for Critical Errors

```lua
-- Core.lua

StaticPopupDialogs["BLOODPACT_CRITICAL_ERROR"] = {
    text = "Blood Pact encountered a critical error:\n\n%s\n\nPlease report this to the addon author.",
    button1 = "Okay",
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1
}
```

### Protected Function Calls

```lua
-- Wrap risky operations in pcall to prevent addon from crashing WoW client

function BloodPact_SafeCall(func, ...)
    local success, result = pcall(func, unpack(arg))
    
    if not success then
        BloodPact_Logger:Error("Function call failed: " .. tostring(result))
        return nil
    end
    
    return result
end

-- Usage example:
BloodPact_SafeCall(BloodPact_DeathDetector.ConfirmAndLogDeath, BloodPact_DeathDetector)
```

---

## Performance Optimization

### Memory Management

```lua
-- Limit SavedVariables growth
function BloodPact_DeathDataManager:EnforceSizeLimit()
    if not BloodPactAccountDB or not BloodPactAccountDB.deaths then
        return
    end
    
    for charName, deathList in pairs(BloodPactAccountDB.deaths) do
        -- Enforce 25-death limit per character
        while table.getn(deathList) > 25 do
            table.remove(deathList, 1) -- Remove oldest death (first in array)
        end
    end
end
```

### Event Throttling

```lua
-- Combat log events can fire very frequently
-- Throttle processing to prevent FPS drops

local THROTTLE_INTERVAL = 0.1 -- 100ms
local lastProcessTime = 0

function BloodPact_ThrottledEventHandler(event, ...)
    local currentTime = GetTime()
    
    if currentTime - lastProcessTime < THROTTLE_INTERVAL then
        return -- Skip this event
    end
    
    lastProcessTime = currentTime
    
    -- Process event
    BloodPact_OnEvent(event, unpack(arg))
end
```

### Batch SavedVariables Writes

```lua
-- Don't write to SavedVariables on every death (expensive I/O)
-- Batch writes and flush on logout

BloodPact_DeathDataManager = {
    dirtyFlag = false
}

function BloodPact_DeathDataManager:RecordDeath(deathRecord)
    -- Add to in-memory structure
    local charName = deathRecord.characterName
    
    if not BloodPactAccountDB.deaths[charName] then
        BloodPactAccountDB.deaths[charName] = {}
    end
    
    table.insert(BloodPactAccountDB.deaths[charName], deathRecord)
    
    -- Mark data as dirty (will be saved on logout)
    self.dirtyFlag = true
    
    -- Enforce size limit
    self:EnforceSizeLimit()
end

function BloodPact_DeathDataManager:OnPlayerLogout()
    if self.dirtyFlag then
        -- SavedVariables automatically written
        -- No explicit flush needed in WoW 1.12
        self.dirtyFlag = false
    end
end
```

### UI Frame Optimization

```lua
-- Hide UI frames during combat to save FPS
function BloodPact_MainFrame:OnCombatStart()
    if self.frame and self.frame:IsVisible() then
        self.frame:Hide()
        self.hiddenDueCombat = true
    end
end

function BloodPact_MainFrame:OnCombatEnd()
    if self.hiddenDueCombat then
        self.frame:Show()
        self.hiddenDueCombat = false
    end
end
```

---

## WoW 1.12 API Constraints

### Available APIs (Confirmed for 1.12)

- `UnitName("player")` - Get character name
- `UnitLevel("player")` - Get character level
- `UnitClass("player")` - Get character class
- `UnitRace("player")` - Get character race
- `UnitXP("player")` - Get current level XP
- `UnitXPMax("player")` - Get XP needed for next level
- `GetZoneText()` - Get current zone name
- `GetSubZoneText()` - Get current subzone name
- `GetPlayerMapPosition("player")` - Get map coordinates
- `GetMoney()` - Get player currency in copper
- `GetInventoryItemLink("player", slotID)` - Get equipped item link
- `GetItemInfo(itemID)` - Get item details
- `time()` - Get Unix timestamp
- `date(format, timestamp)` - Format timestamp as string
- `GetTime()` - Get elapsed time in seconds since client launch
- `SendAddonMessage(prefix, message, channel)` - Send addon message
- `CreateFrame(type, name, parent, template)` - Create UI frame
- `DEFAULT_CHAT_FRAME:AddMessage(text)` - Print to chat

### API Limitations

1. **No GetNumTitles() / GetTitleName()** - These may not exist in 1.12
   - **Workaround:** Use combat log parsing or manual player flag
   - Check for existence: `if GetNumTitles then ... end`

2. **No C_Timer API** - Retail timer functions not available
   - **Workaround:** Use `OnUpdate` script handlers for timing

3. **No Table.wipe()** - Lua 5.1 doesn't have table.wipe
   - **Workaround:** Use `for k in pairs(t) do t[k] = nil end`

4. **Addon Message Size Limit:** 255 bytes
   - **Mitigation:** Chunk large messages

5. **No SendAddonMessageLogged** - Only basic `SendAddonMessage`

6. **Limited String Library** - Some modern string functions unavailable
   - Use: `string.len`, `string.sub`, `string.find`, `string.gsub`, `string.format`

### Lua 5.1 Syntax Requirements

```lua
-- Use unpack(arg), not ... in varargs
function MyFunction(...)
    local args = arg -- WoW 1.12 compatibility
    local firstArg = unpack(args)
end

-- Use table.getn(), not #
local length = table.getn(myTable) -- Not #myTable

-- Use table.insert/remove, not table.pack/unpack
table.insert(myTable, value)
local value = table.remove(myTable, index)

-- No table.foreach (deprecated), use pairs/ipairs
for k, v in pairs(myTable) do
    -- ...
end

-- No bit operations (bit.band, etc. added in Lua 5.2)
-- Use math operators if needed

-- No goto statements (Lua 5.2+)
```

### Title Detection Fallback

```lua
-- If GetNumTitles() unavailable, use alternative detection
function BloodPact_DeathDetector:IsHardcoreCharacter()
    -- Method 1: Try title API (may not exist in 1.12)
    if GetNumTitles then
        local numTitles = GetNumTitles()
        for i = 1, numTitles do
            local titleName = GetTitleName(i)
            if titleName and string.find(titleName, "Still Alive") then
                return true
            end
        end
        return false
    end
    
    -- Method 2: Fallback - require manual flag in UI
    -- Player must manually enable "I am hardcore" checkbox
    if BloodPactAccountDB and BloodPactAccountDB.config then
        return BloodPactAccountDB.config.manualHardcoreFlag == true
    end
    
    return false
end
```

---

## Security Considerations

### Join Code Entropy

- 8 alphanumeric characters = 36^8 = 2.8 trillion combinations
- Brute force infeasible in addon context (no server, no API)

### Addon Message Validation

```lua
function BloodPact_SyncEngine:ValidateMessage(data)
    -- Check message structure
    if type(data) ~= "table" then
        return false
    end
    
    if not data.msgType or not data.senderAccountID then
        return false
    end
    
    -- Check timestamp is reasonable (within 1 year)
    local currentTime = time()
    if math.abs(data.timestamp - currentTime) > 31536000 then
        return false
    end
    
    return true
end
```

### SavedVariables Corruption Protection

```lua
-- Detect and isolate corrupted data
function BloodPact_SavedVariablesHandler:RepairCorruption()
    if not BloodPactAccountDB then
        return
    end
    
    -- Check each death record
    for charName, deathList in pairs(BloodPactAccountDB.deaths) do
        for i = table.getn(deathList), 1, -1 do
            local death = deathList[i]
            
            -- Validate required fields
            if not death.characterName or not death.timestamp or not death.level then
                -- Corrupted record, remove it
                table.remove(deathList, i)
                BloodPact_Logger:Warning(
                    "Removed corrupted death record for character: " .. charName
                )
            end
        end
    end
end
```

---

## Testing Strategy

### Unit Test Coverage (Manual Testing)

1. **Death Detection**
   - Kill hardcore character with NPC
   - Kill hardcore character with fall damage
   - Kill hardcore character with drowning
   - Verify softcore characters not tracked

2. **Pact Creation**
   - Create pact with valid name
   - Verify join code generated
   - Verify join code format

3. **Pact Joining**
   - Join pact with valid code
   - Attempt join with invalid code
   - Attempt join while already in pact

4. **Synchronization**
   - Two players in same pact
   - Player A dies, verify Player B sees death
   - Both players die simultaneously
   - Player joins while others offline

5. **Data Export**
   - Export personal data
   - Export pact data
   - Verify JSON validity

6. **Data Wipe**
   - Wipe data
   - Verify deaths cleared
   - Verify account ID preserved

### Performance Benchmarks

- Memory usage < 5MB baseline
- Death detection latency < 1 second
- UI frame render < 5ms per frame
- Pact sync latency < 10 seconds (normal network)

### Edge Cases

- Empty death history
- 25th+ death (pruning)
- Pact with 1 member
- Pact with 40 members
- Pact owner leaves game
- SavedVariables file deleted
- Addon disabled then re-enabled

---

## Deployment Checklist

- [ ] All TOC fields completed
- [ ] Version number set in TOC and Config.lua
- [ ] All Lua files included in TOC
- [ ] SavedVariables declared in TOC
- [ ] No syntax errors (`luac -p *.lua`)
- [ ] All slash commands tested
- [ ] UI frames tested at different resolutions
- [ ] Addon message prefix registered
- [ ] Error handling tested
- [ ] Performance profiled
- [ ] User documentation written
- [ ] README.md with installation instructions
- [ ] CHANGELOG.md with version history

---

## Future Enhancements (Post-1.0)

- Multiple pact membership
- Pact leaving/disbanding mechanics
- Death cause analytics and statistics
- In-game achievements and milestones
- Death notifications for pact members
- Web API integration for external stats
- Graphical timeline improvements
- Cross-server pact support (very difficult)

---

## Appendix A: Serialization Library

```lua
-- Utils/Serialization.lua
-- Simple table serialization for addon messages

BloodPact_Serialization = {}

function BloodPact_Serialization:Serialize(data)
    -- Convert table to string representation
    -- Format: key1=value1;key2=value2;...
    -- Nested tables: key={nestedKey=nestedValue}
    
    local function serializeValue(val)
        if type(val) == "string" then
            return "'" .. val .. "'"
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "boolean" then
            return tostring(val)
        elseif type(val) == "table" then
            return "{" .. self:Serialize(val) .. "}"
        else
            return "nil"
        end
    end
    
    local parts = {}
    for k, v in pairs(data) do
        local serializedKey = serializeValue(k)
        local serializedValue = serializeValue(v)
        table.insert(parts, serializedKey .. "=" .. serializedValue)
    end
    
    return table.concat(parts, ";")
end

function BloodPact_Serialization:Deserialize(str)
    -- Parse serialized string back to table
    -- Very basic implementation - production would use AceSerializer or similar
    
    -- TODO: Implement robust deserialization
    -- For v1.0, consider using a simpler format or existing library
    
    return {}
end
```

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-07 | Justin | Initial technical design |

---

**End of Technical Design Document**
