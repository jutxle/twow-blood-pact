-- Blood Pact - Logger
-- Color-coded chat output for debug/info/warning/error messages

-- ============================================================
-- Lua 5.0 compatibility shims (WoW 1.12 uses Lua 5.0)
-- ============================================================

-- string.match was added in Lua 5.1; polyfill for Lua 5.0
if not string.match then
    string.match = function(s, pattern, init)
        local t = {string.find(s, pattern, init)}
        if not t[1] then return nil end
        if table.getn(t) > 2 then
            local caps = {}
            for i = 3, table.getn(t) do
                caps[i - 2] = t[i]
            end
            return unpack(caps)
        else
            return string.sub(s, t[1], t[2])
        end
    end
end

BloodPact_Logger = {}

BloodPact_Logger.LEVEL = {
    DEBUG   = 0,
    INFO    = 1,
    WARNING = 2,
    ERROR   = 3
}

-- Default: show warnings and errors only
BloodPact_Logger.currentLevel = BloodPact_Logger.LEVEL.WARNING

-- Safe wrapper for AddMessage - catches invalid escape code errors
local function SafeAddMessage(text)
    local ok, err = pcall(function()
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end)
    if not ok then
        -- Strip all pipe characters and retry
        local safe = string.gsub(text, "|", "")
        DEFAULT_CHAT_FRAME:AddMessage("[BP-ESCAPED] " .. safe .. " (original error: " .. tostring(err) .. ")")
    end
end

function BloodPact_Logger:SetLevel(level)
    self.currentLevel = level
end

function BloodPact_Logger:Debug(msg, category)
    if self.currentLevel > self.LEVEL.DEBUG then return end
    local prefix = "[BloodPact]"
    if category then prefix = prefix .. "[" .. category .. "]" end
    SafeAddMessage(prefix .. " DEBUG: " .. tostring(msg))
end

function BloodPact_Logger:Info(msg, category)
    if self.currentLevel > self.LEVEL.INFO then return end
    local prefix = "[BloodPact]"
    if category then prefix = prefix .. "[" .. category .. "]" end
    SafeAddMessage(prefix .. " " .. tostring(msg))
end

function BloodPact_Logger:Warning(msg, category)
    if self.currentLevel > self.LEVEL.WARNING then return end
    local prefix = "[BloodPact]"
    if category then prefix = prefix .. "[" .. category .. "]" end
    SafeAddMessage(prefix .. " WARNING: " .. tostring(msg))
end

function BloodPact_Logger:Error(msg, category)
    if self.currentLevel > self.LEVEL.ERROR then return end
    local prefix = "[BloodPact]"
    if category then prefix = prefix .. "[" .. category .. "]" end
    SafeAddMessage(prefix .. " ERROR: " .. tostring(msg))

    -- Auto-persist to error log with stack trace
    local stack = debugstack and debugstack(2, 8, 0) or nil
    if BloodPact_Debug then
        BloodPact_Debug:LogError(tostring(msg), stack, category)
    end

    -- Show stack in chat when at DEBUG level
    if stack and self.currentLevel <= self.LEVEL.DEBUG then
        SafeAddMessage("[BloodPact] Stack: " .. stack)
    end
end

-- Always shown regardless of log level
function BloodPact_Logger:Print(msg)
    SafeAddMessage("[BloodPact] " .. tostring(msg))
end
