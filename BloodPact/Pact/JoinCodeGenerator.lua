-- Blood Pact - Join Code Generator
-- Generates and validates 8-character alphanumeric pact join codes

BloodPact_JoinCodeGenerator = {}

local CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local CODE_LENGTH = 8

-- Generate a new random join code
function BloodPact_JoinCodeGenerator:GenerateCode()
    local code = ""
    local len = string.len(CHARSET)
    for i = 1, CODE_LENGTH do
        local idx = math.random(1, len)
        code = code .. string.sub(CHARSET, idx, idx)
    end
    return code
end

-- Validate that a code matches the expected format (8 alphanumeric chars)
function BloodPact_JoinCodeGenerator:ValidateCodeFormat(code)
    if type(code) ~= "string" then return false end
    if string.len(code) ~= CODE_LENGTH then return false end

    for i = 1, CODE_LENGTH do
        local c = string.sub(code, i, i)
        if not string.find(c, "[A-Za-z0-9]") then
            return false
        end
    end

    return true
end
