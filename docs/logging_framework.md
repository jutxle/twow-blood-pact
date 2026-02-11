# Blood Pact - Debug Framework

## Context

The addon lacks actionable error capture. When frame scripts error silently or network messages fail, there's no persistent record. The existing `BloodPact_Logger` only outputs to chat (ephemeral) and has no stack traces, categories, or persistent storage. Debugging requires `/bp debug` and hoping to reproduce the issue while watching chat.

**Goal:** Add a lightweight debug framework that persists errors to SavedVariables, captures stack traces, wraps frame scripts safely, and provides actionable slash commands for diagnosis.

**Confirmed:** WoW 1.12 uses **Lua 5.0** (not 5.1). Available debug APIs: `pcall()`, `debugstack()`, `debugprofilestart()`/`debugprofilestop()`. NOT available: `xpcall()`, `seterrorhandler()`.

---

## Files to Change

| File | Action | Purpose |
|------|--------|---------|
| `Utils/Debug.lua` | **CREATE** | Core debug module: error log, SafeCall, WrapScript, tracing, profiling |
| `Utils/Logger.lua` | MODIFY | Add DEBUG level, category tags, auto-persist errors, stack traces |
| `Commands/CommandHandler.lua` | MODIFY | Add `/bp errors`, `/bp clearerrors`, `/bp trace`, `/bp dump`, `/bp profile` |
| `Data/SavedVariablesHandler.lua` | MODIFY | Initialize `BloodPactAccountDB.debug` storage |
| `Pact/SyncEngine.lua` | MODIFY | Add trace hooks for incoming/outgoing messages |
| `Core.lua` | MODIFY | Wrap OnEvent/OnUpdate handlers with error capture |
| `BloodPact.toc` | MODIFY | Add `Utils\Debug.lua` to load order |

---

## Step 1: TOC Load Order

Insert `Utils\Debug.lua` immediately after `Utils\Logger.lua`:

```
Utils\Logger.lua
Utils\Debug.lua          ← NEW
Utils\Serialization.lua
```

Debug.lua depends on Logger. All other modules can use Debug.

---

## Step 2: Create `Utils/Debug.lua`

### 2a. Persistent Error Log (ring buffer in SavedVariables)

```lua
BloodPact_Debug = {}
BLOODPACT_DEBUG_MAX_ERRORS = 50

function BloodPact_Debug:LogError(message, stack, category)
    -- Guard: DB may not be loaded yet
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
```

### 2b. SafeCall Wrapper

```lua
-- Supports up to 8 explicit args (Lua 5.0 has no varargs in function bodies)
-- Captures call-site stack BEFORE pcall (pcall unwinds the stack)
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
```

### 2c. Frame Script Error Capture

```lua
-- Wrap a single script handler on a frame with pcall error capture
function BloodPact_Debug:WrapScript(frame, scriptType)
    if not frame then return end
    local original = frame:GetScript(scriptType)
    if not original then return end

    local frameName = (frame:GetName() or "anon") .. ":" .. scriptType

    frame:SetScript(scriptType, function()
        -- WoW 1.12: frame script args come via globals (this, event, arg1...)
        local preStack = debugstack and debugstack(2, 8, 0) or nil
        local ok, err = pcall(original)
        if not ok then
            local errMsg = "[" .. frameName .. "] " .. tostring(err)
            BloodPact_Debug:LogError(errMsg, preStack, "UI")
            BloodPact_Logger:Error(errMsg)
        end
    end)
end

-- Convenience: wrap all common scripts on a frame
function BloodPact_Debug:WrapAllScripts(frame)
    local scripts = {"OnClick", "OnUpdate", "OnEvent", "OnShow", "OnHide",
                     "OnEnter", "OnLeave", "OnMouseWheel"}
    for _, s in ipairs(scripts) do
        if frame:GetScript(s) then
            self:WrapScript(frame, s)
        end
    end
end
```

### 2d. Network Message Tracing

```lua
BloodPact_Debug._traceEnabled = false

function BloodPact_Debug:IsTraceEnabled() return self._traceEnabled == true end
function BloodPact_Debug:SetTraceEnabled(enabled) self._traceEnabled = enabled end

function BloodPact_Debug:TraceOutgoing(msg, channel)
    if not self._traceEnabled then return end
    local msgType = string.sub(msg, 1, (string.find(msg, "~", 1, true) or 4) - 1)
    BloodPact_Logger:Print("[TRACE OUT][" .. (channel or "?") .. "] " .. msgType .. " (" .. string.len(msg) .. "b)")
end

function BloodPact_Debug:TraceIncoming(msg, channel, sender)
    if not self._traceEnabled then return end
    local msgType = string.sub(msg, 1, (string.find(msg, "~", 1, true) or 4) - 1)
    BloodPact_Logger:Print("[TRACE IN][" .. (channel or "?") .. "] " .. msgType .. " (" .. string.len(msg) .. "b) from " .. tostring(sender))
end
```

### 2e. Performance Profiling

```lua
-- Uses debugprofilestart()/debugprofilestop() - single global timer, cannot nest
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
```

### 2f. State Dump

```lua
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
```

---

## Step 3: Modify `Utils/Logger.lua`

### 3a. Add DEBUG level (value 0)

```lua
BloodPact_Logger.LEVEL = {
    DEBUG   = 0,   -- NEW: very verbose
    INFO    = 1,
    WARNING = 2,
    ERROR   = 3
}
```

### 3b. Add `Debug()` method

```lua
function BloodPact_Logger:Debug(msg, category)
    if self.currentLevel > self.LEVEL.DEBUG then return end
    local prefix = "[BloodPact]"
    if category then prefix = prefix .. "[" .. category .. "]" end
    SafeAddMessage(prefix .. " DEBUG: " .. tostring(msg))
end
```

### 3c. Add optional `category` param to Info/Warning/Error

All existing single-arg calls continue working unchanged (second param defaults to nil):

```lua
function BloodPact_Logger:Info(msg, category)
    if self.currentLevel > self.LEVEL.INFO then return end
    local prefix = "[BloodPact]"
    if category then prefix = prefix .. "[" .. category .. "]" end
    SafeAddMessage(prefix .. " " .. tostring(msg))
end
```

Same pattern for `:Warning(msg, category)`.

### 3d. Enhance `Error()` to auto-persist and capture stack

```lua
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
```

---

## Step 4: Modify `Data/SavedVariablesHandler.lua`

Add after the `config` validation block (around line 41), before death record validation:

```lua
-- Ensure debug storage exists
if not BloodPactAccountDB.debug then
    BloodPactAccountDB.debug = { errorLog = {} }
end
if not BloodPactAccountDB.debug.errorLog then
    BloodPactAccountDB.debug.errorLog = {}
end
```

---

## Step 5: Modify `Pact/SyncEngine.lua`

### 5a. Trace incoming messages

At top of `OnAddonMessage()` (after `if not msg then return end`):

```lua
if BloodPact_Debug and BloodPact_Debug:IsTraceEnabled() then
    BloodPact_Debug:TraceIncoming(msg, channel, sender)
end
```

### 5b. Trace outgoing messages

In `SendOnAllChannels()`, before each `pcall(SendAddonMessage, ...)` call, add the appropriate trace:

```lua
if BloodPact_Debug and BloodPact_Debug:IsTraceEnabled() then
    BloodPact_Debug:TraceOutgoing(msg, "GUILD")  -- or "RAID" / "PARTY"
end
```

---

## Step 6: Modify `Core.lua`

At the **bottom** of the file (after event registration), wrap the main frame handlers:

```lua
-- Wrap main event/update handlers for error capture
if BloodPact_Debug then
    local originalOnEvent = BloodPactFrame:GetScript("OnEvent")
    if originalOnEvent then
        BloodPactFrame:SetScript("OnEvent", function()
            local ok, err = pcall(originalOnEvent)
            if not ok then
                BloodPact_Debug:LogError("[OnEvent:" .. tostring(event) .. "] " .. tostring(err),
                    debugstack and debugstack(2, 8, 0) or nil, "CORE")
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("[BloodPact] ERROR in " .. tostring(event) .. ": " .. tostring(err))
                end
            end
        end)
    end

    BloodPact_Debug:WrapScript(BloodPactFrame, "OnUpdate")
end
```

---

## Step 7: Modify `Commands/CommandHandler.lua`

### 7a. Update existing `debug` command

Change from INFO to DEBUG level:

```lua
elseif input == "debug" then
    BloodPact_Logger:SetLevel(BloodPact_Logger.LEVEL.DEBUG)
    BloodPact_Logger:Print("Verbose debug logging enabled.")
```

### 7b. Add new commands (before the `else` catch-all)

```lua
elseif input == "errors" then
    self:ShowErrors()
elseif input == "clearerrors" then
    BloodPact_Debug:ClearErrorLog()
    BloodPact_Logger:Print("Error log cleared.")
elseif input == "trace" then
    local current = BloodPact_Debug:IsTraceEnabled()
    BloodPact_Debug:SetTraceEnabled(not current)
    BloodPact_Logger:Print("Message tracing: " .. (not current and "ENABLED" or "DISABLED"))
elseif input == "dump" then
    BloodPact_Debug:DumpState()
elseif string.sub(input, 1, 8) == "profile " or input == "profile" then
    local sub = ""
    if string.len(input) > 8 then sub = string.sub(input, 9) end
    self:HandleProfile(sub)
```

### 7c. New handler methods

```lua
function BloodPact_CommandHandler:ShowErrors()
    local errors = BloodPact_Debug:GetErrorLog()
    local count = table.getn(errors)
    if count == 0 then
        BloodPact_Logger:Print("No errors in log.")
        return
    end
    BloodPact_Logger:Print("=== Error Log (" .. tostring(count) .. " entries) ===")
    local startIdx = math.max(1, count - 9)
    for i = startIdx, count do
        local e = errors[i]
        local ts = date("%H:%M:%S", e.timestamp)
        local countStr = (e.count and e.count > 1) and (" (x" .. tostring(e.count) .. ")") or ""
        local catStr = e.category and ("[" .. e.category .. "] ") or ""
        BloodPact_Logger:Print("[" .. ts .. "] " .. catStr .. tostring(e.message) .. countStr)
    end
    if startIdx > 1 then
        BloodPact_Logger:Print("(" .. tostring(startIdx - 1) .. " older entries hidden)")
    end
end

function BloodPact_CommandHandler:HandleProfile(sub)
    if sub == "clear" then
        BloodPact_Debug:ClearProfiles()
        BloodPact_Logger:Print("Profile data cleared.")
    elseif sub == "show" or sub == "" then
        local profiles = BloodPact_Debug:GetProfiles()
        local hasAny = false
        for label, data in pairs(profiles) do
            hasAny = true
            BloodPact_Logger:Print(label .. ": " .. tostring(data.callCount or 0) .. " calls, " ..
                string.format("%.1f", data.totalMs or 0) .. "ms total")
        end
        if not hasAny then BloodPact_Logger:Print("No profile data.") end
    else
        BloodPact_Logger:Print("Usage: /bp profile [show|clear]")
    end
end
```

### 7d. Update help text

Add these lines to `ShowHelp()`:

```
  /bp errors        - Show recent errors from persistent log
  /bp clearerrors   - Clear the error log
  /bp trace         - Toggle addon message tracing
  /bp dump          - Dump addon state to chat
  /bp profile       - Show/clear performance profiles
```

---

## New Slash Commands Summary

| Command | Action |
|---------|--------|
| `/bp debug` | Set log level to DEBUG (was INFO) - most verbose |
| `/bp nodebug` | Set log level to WARNING (unchanged) |
| `/bp errors` | Show last 10 errors from persistent log |
| `/bp clearerrors` | Clear the persistent error log |
| `/bp trace` | Toggle network message tracing on/off |
| `/bp dump` | Print full addon state snapshot |
| `/bp profile` | Show performance profile data |
| `/bp profile clear` | Clear profile accumulators |

---

## Verification

1. **Error persistence:** `/bp debug` → trigger a known error (e.g. open timeline with no data) → `/reload` → `/bp errors` → verify error shows with timestamp and message
2. **Stack traces:** `/bp debug` → trigger error → verify stack trace appears in chat
3. **Message tracing:** `/bp trace` → `/bp simdeath TestPlayer` → verify TRACE IN/OUT messages in chat
4. **State dump:** `/bp dump` → verify account ID, DB version, pact status, log level all display
5. **Error coalescing:** Trigger same error rapidly → `/bp errors` → verify shows "(xN)" count instead of N separate entries
6. **OnEvent wrapping:** Introduce a temporary error in an event handler → verify it's caught and logged instead of silently failing
7. **Zero overhead when off:** With default WARNING level, verify no performance impact (no string concatenation for debug/info messages)
