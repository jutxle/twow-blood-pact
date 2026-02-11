-- Blood Pact - Debug Framework
-- Persistent error log, SafeCall, WrapScript, tracing, profiling
-- Lua 5.0 compatible (WoW 1.12)

BloodPact_Debug = {}
BLOODPACT_DEBUG_MAX_ERRORS = 50

-- ============================================================
-- 2a. Persistent Error Log (ring buffer in SavedVariables)
-- ============================================================

function BloodPact_Debug:LogError(message, stack, category)
    if not BloodPactAccountDB then return end
    if not BloodPactAccountDB.debug then BloodPactAccountDB.debug = { errorLog = {} } end
    local log = BloodPactAccountDB.debug.errorLog

    -- Coalesce repeated identical errors within 60s
    local n = table.getn(log)
    if n > 0 then
        local last = log[n]
        if last.message == message and (time() - last.timestamp) < 60 then
            last.count = (last.count or 1) + 1
            return
        end
    end

    -- Append new entry
    table.insert(log, {
        timestamp = time(),
        message   = tostring(message),
        stack     = stack,
        category  = category,
        count     = 1
    })

    -- Enforce ring buffer max
    while table.getn(log) > BLOODPACT_DEBUG_MAX_ERRORS do
        table.remove(log, 1)
    end
end

function BloodPact_Debug:GetErrorLog()
    if not BloodPactAccountDB or not BloodPactAccountDB.debug then return {} end
    return BloodPactAccountDB.debug.errorLog or {}
end

function BloodPact_Debug:ClearErrorLog()
    if BloodPactAccountDB and BloodPactAccountDB.debug then
        BloodPactAccountDB.debug.errorLog = {}
    end
end

-- ============================================================
-- 2b. SafeCall Wrapper (up to 8 args - Lua 5.0)
-- ============================================================

function BloodPact_Debug:SafeCall(func, a1, a2, a3, a4, a5, a6, a7, a8)
    local preStack = debugstack and debugstack(2, 12, 0) or nil
    local ok, result = pcall(func, a1, a2, a3, a4, a5, a6, a7, a8)
    if not ok then
        local errMsg = tostring(result)
        self:LogError(errMsg, preStack, nil)
        BloodPact_Logger:Error(errMsg)
        if preStack and BloodPact_Logger.currentLevel <= BloodPact_Logger.LEVEL.INFO then
            BloodPact_Logger:Info("Stack: " .. preStack)
        end
    end
    return ok, result
end

-- ============================================================
-- 2c. Frame Script Error Capture
-- ============================================================

function BloodPact_Debug:WrapScript(frame, scriptType)
    if not frame then return end
    local original = frame:GetScript(scriptType)
    if not original then return end

    local frameName = (frame:GetName() or "anon") .. ":" .. scriptType

    frame:SetScript(scriptType, function()
        local preStack = debugstack and debugstack(2, 8, 0) or nil
        local ok, err = pcall(original)
        if not ok then
            local errMsg = "[" .. frameName .. "] " .. tostring(err)
            BloodPact_Debug:LogError(errMsg, preStack, "UI")
            BloodPact_Logger:Error(errMsg)
        end
    end)
end

function BloodPact_Debug:WrapAllScripts(frame)
    local scripts = {"OnClick", "OnUpdate", "OnEvent", "OnShow", "OnHide",
                     "OnEnter", "OnLeave", "OnMouseWheel"}
    for _, s in ipairs(scripts) do
        if frame:GetScript(s) then
            self:WrapScript(frame, s)
        end
    end
end

-- ============================================================
-- 2d. Network Message Tracing
-- ============================================================

BloodPact_Debug._traceEnabled = false

function BloodPact_Debug:IsTraceEnabled() return self._traceEnabled == true end
function BloodPact_Debug:SetTraceEnabled(enabled) self._traceEnabled = enabled end

function BloodPact_Debug:TraceOutgoing(msg, channel)
    if not self._traceEnabled then return end
    local pos = string.find(msg, "~")
    local msgType = string.sub(msg, 1, (pos or 4) - 1)
    BloodPact_Logger:Print("[TRACE OUT][" .. (channel or "?") .. "] " .. msgType .. " (" .. string.len(msg) .. "b)")
end

function BloodPact_Debug:TraceIncoming(msg, channel, sender)
    if not self._traceEnabled then return end
    local pos = string.find(msg, "~")
    local msgType = string.sub(msg, 1, (pos or 4) - 1)
    BloodPact_Logger:Print("[TRACE IN][" .. (channel or "?") .. "] " .. msgType .. " (" .. string.len(msg) .. "b) from " .. tostring(sender))
end

-- ============================================================
-- 2e. Performance Profiling
-- ============================================================

BloodPact_Debug._profiles = {}

function BloodPact_Debug:ProfileStart(label)
    if not debugprofilestart then return end
    debugprofilestart()
    self._profiles[label] = self._profiles[label] or { totalMs = 0, callCount = 0 }
end

function BloodPact_Debug:ProfileStop(label)
    if not debugprofilestop then return end
    local elapsed = debugprofilestop()
    local p = self._profiles[label]
    if not p then return end
    p.totalMs = p.totalMs + elapsed
    p.callCount = p.callCount + 1
    p.lastMs = elapsed
end

function BloodPact_Debug:GetProfiles() return self._profiles end
function BloodPact_Debug:ClearProfiles() self._profiles = {} end

-- ============================================================
-- 2f. State Dump
-- ============================================================

function BloodPact_Debug:DumpState()
    BloodPact_Logger:Print("=== BloodPact Debug Dump ===")

    local accountID = BloodPact_AccountIdentity and BloodPact_AccountIdentity:GetAccountID() or "N/A"
    BloodPact_Logger:Print("Account ID: " .. tostring(accountID))

    if BloodPactAccountDB then
        BloodPact_Logger:Print("DB version: " .. tostring(BloodPactAccountDB.version))
        local charCount = 0
        if BloodPactAccountDB.characters then
            for _ in pairs(BloodPactAccountDB.characters) do charCount = charCount + 1 end
        end
        BloodPact_Logger:Print("Characters: " .. tostring(charCount))
    else
        BloodPact_Logger:Print("DB: NOT LOADED")
    end

    if BloodPact_PactManager and BloodPact_PactManager:IsInPact() then
        local pact = BloodPactAccountDB.pact
        BloodPact_Logger:Print("Pact: " .. tostring(pact.pactName) .. " [" .. tostring(pact.joinCode) .. "]")
        local memberCount = 0
        if pact.members then for _ in pairs(pact.members) do memberCount = memberCount + 1 end end
        BloodPact_Logger:Print("Members: " .. tostring(memberCount))
    else
        BloodPact_Logger:Print("Pact: NONE")
    end

    BloodPact_Logger:Print("Log level: " .. tostring(BloodPact_Logger.currentLevel))
    BloodPact_Logger:Print("Trace: " .. (self:IsTraceEnabled() and "ON" or "OFF"))
    BloodPact_Logger:Print("Persisted errors: " .. tostring(table.getn(self:GetErrorLog())))

    local profileCount = 0
    for label, data in pairs(self._profiles) do
        profileCount = profileCount + 1
        BloodPact_Logger:Print("  Profile [" .. label .. "]: " ..
            tostring(data.callCount or 0) .. " calls, " ..
            string.format("%.1f", data.totalMs or 0) .. "ms total")
    end

    BloodPact_Logger:Print("=== End Dump ===")
end
