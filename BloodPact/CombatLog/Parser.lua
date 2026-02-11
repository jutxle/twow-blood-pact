-- Blood Pact - Combat Log Parser
-- Parses raw combat log messages to detect deaths and track last attacker

BloodPact_Parser = {}

-- Ring buffer for last attacker tracking (last 5 damage-to-player messages)
-- Each entry: { name = string, ability = string or nil }
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

-- Parse killer from death message. Most reliable source when available.
-- Formats: "X is slain by Y.", "X have been slain by Y!", "X dies." (no killer)
function BloodPact_Parser:ParseKillerFromDeathMessage(msg)
    if not msg then return nil end
    -- "slain by X" or "slain by X!" - capture X
    local killer = string.match(msg, "slain by (.+)")
    if killer then
        -- Strip trailing punctuation and whitespace
        killer = string.gsub(killer, "[%.!%?%s]+$", "")
        -- Strip WoW link brackets: [Stitches] -> Stitches
        killer = string.gsub(killer, "^%[(.+)%]$", "%1")
        if string.len(killer) > 0 then return killer end
    end
    return nil
end

-- Parse damage-to-player messages to track last attacker and ability
-- CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS: "X hits you for N damage."
-- CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE: "X's SpellName hits you for N damage."
-- CHAT_MSG_COMBAT_CREATURE_VS_SELF_DAMAGE: similar for periodic/dot
function BloodPact_Parser:ParseAttackerFromHitMessage(msg)
    if not msg then return nil, nil end

    local attacker, ability = nil, nil

    -- Pattern: "X's Ability hits you for..." or "X's Ability crits you for..."
    local hitMatch = string.match(msg, "^(.+) hits you for")
    if not hitMatch then
        hitMatch = string.match(msg, "^(.+) crits you for")
    end
    if hitMatch then
        -- Check for "X's Y" format - X is attacker, Y is ability
        local a, b = string.match(hitMatch, "^(.+)'s (.+)$")
        if a and b then
            attacker, ability = a, b
        else
            attacker = hitMatch
            ability = "Melee"
        end
        return attacker, ability
    end

    -- "You suffer N from X's SpellName" (periodic/DoT damage)
    attacker, ability = string.match(msg, " from ([^']+)'s ([^%.%!]+)")
    if attacker and ability then
        return attacker, ability
    end

    return nil, nil
end

-- Store an attacker in the ring buffer (name, ability)
function BloodPact_Parser:RecordAttacker(name, ability)
    if not name then return end
    self.attackerBufferPos = math.mod(self.attackerBufferPos, ATTACKER_BUFFER_SIZE) + 1
    self.attackerBuffer[self.attackerBufferPos] = {
        name = name,
        ability = ability or "Melee"
    }
end

-- Get the most recent attacker from the buffer
-- Returns name, ability (or nil, nil)
function BloodPact_Parser:GetLastAttacker()
    if self.attackerBufferPos == 0 then return nil, nil end
    local entry = self.attackerBuffer[self.attackerBufferPos]
    if not entry then return nil, nil end
    return entry.name, entry.ability
end

-- Clear the attacker buffer
function BloodPact_Parser:ClearAttackerBuffer()
    self.attackerBuffer = {}
    self.attackerBufferPos = 0
end
