-- Blood Pact - Character Identity
-- Generates unique character instance IDs when a character dies.
-- Used to distinguish between "Bob" (deleted after death) and "Bob" (recreated).
-- Upon death we know the character's lifecycle ended; next login with that name is a new character.

BloodPact_CharacterIdentity = {}

-- Generate a unique character instance ID.
-- Format: timestamp_random (e.g. "1739123456_4827") for uniqueness.
function BloodPact_CharacterIdentity:GenerateInstanceID()
    return tostring(time()) .. "_" .. string.format("%04d", math.random(1000, 9999))
end
