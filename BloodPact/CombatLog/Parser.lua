-- Blood Pact - Combat Log Parser
-- Parses raw combat log messages to detect deaths and track last attacker

BloodPact_Parser = {}

-- Ring buffer for last attacker tracking (last 5 damage-to-player messages)
local ATTACKER_BUFFER_SIZE = 5
BloodPact_Parser.attackerBuffer = {}
BloodPact_Parser.attackerBufferPos = 0

-- Check if a CHAT_MSG_COMBAT_HOSTILE_DEATH message indicates the player died
-- Message formats: "X dies.", "X is slain by Y.", etc.
function BloodPact_Parser:IsPlayerDeathMessage(msg)
    if not msg then return false end
    local playerName = UnitName("player")
    if not playerName then return false end

    -- Check if player name appears in the message
    if not string.find(msg, playerName, 1, true) then
        return false
    end

    -- Verify it's a death message (not just a mention)
    if string.find(msg, "dies", 1, true) or
       string.find(msg, "is slain", 1, true) or
       string.find(msg, "have been slain", 1, true) then
        return true
    end

    return false
end

-- Parse damage-to-player messages to track last attacker
-- CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS format: "X hits you for N damage."
-- CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE: "X's Spell hits you for N damage."
function BloodPact_Parser:ParseAttackerFromHitMessage(msg)
    if not msg then return nil, nil end

    -- Pattern: "X hits you for..." or "X's Y hits you for..."
    local attacker = string.match(msg, "^(.+) hits you for")
    if attacker then
        -- Strip possessive: "X's Spell" -> extract "X"
        local base = string.match(attacker, "^(.+)'s .+$")
        if base then attacker = base end
        return attacker, nil
    end

    -- Pattern: "X crits you for..."
    attacker = string.match(msg, "^(.+) crits you for")
    if attacker then
        local base = string.match(attacker, "^(.+)'s .+$")
        if base then attacker = base end
        return attacker, nil
    end

    return nil, nil
end

-- Store an attacker in the ring buffer
function BloodPact_Parser:RecordAttacker(name)
    if not name then return end
    self.attackerBufferPos = math.mod(self.attackerBufferPos, ATTACKER_BUFFER_SIZE) + 1
    self.attackerBuffer[self.attackerBufferPos] = name
end

-- Get the most recent attacker from the buffer
function BloodPact_Parser:GetLastAttacker()
    if self.attackerBufferPos == 0 then return nil end
    return self.attackerBuffer[self.attackerBufferPos]
end

-- Clear the attacker buffer
function BloodPact_Parser:ClearAttackerBuffer()
    self.attackerBuffer = {}
    self.attackerBufferPos = 0
end
