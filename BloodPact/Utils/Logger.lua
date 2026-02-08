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
    INFO    = 1,
    WARNING = 2,
    ERROR   = 3
}

-- Default: show warnings and errors only
BloodPact_Logger.currentLevel = BloodPact_Logger.LEVEL.WARNING

function BloodPact_Logger:SetLevel(level)
    self.currentLevel = level
end

function BloodPact_Logger:Info(msg)
    if self.currentLevel <= self.LEVEL.INFO then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[BloodPact]|r " .. tostring(msg))
    end
end

function BloodPact_Logger:Warning(msg)
    if self.currentLevel <= self.LEVEL.WARNING then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BloodPact]|r " .. tostring(msg))
    end
end

function BloodPact_Logger:Error(msg)
    if self.currentLevel <= self.LEVEL.ERROR then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444[BloodPact]|r " .. tostring(msg))
    end
end

-- Always shown regardless of log level
function BloodPact_Logger:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600[BloodPact]|r " .. tostring(msg))
end
