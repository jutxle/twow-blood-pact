# Blood Pact - Functional & Code Review

**Date:** February 11, 2025  
**Scope:** Full addon review (functional behavior + code quality)

---

## Executive Summary

Blood Pact is a well-structured hardcore death tracker addon for Turtle WoW. The architecture is clean, separation of concerns is good, and most features work as intended. A few **critical bugs** and several improvements were identified.

| Severity | Count | Summary |
|----------|-------|---------|
| Critical | 2 | Ownership transfer never fires; local death doesn't update pact member stats |
| Medium | 5 | Parser locale, Serialization dead code, arg1 deprecation, etc. |
| Low | 8 | Minor hardening, documentation, consistency |

---

## Part 1: Functional Review

### 1.1 Death Detection Pipeline

**Flow:** `CHAT_MSG_COMBAT_HOSTILE_DEATH` / `PLAYER_DEAD` → DeathDetector state machine → DataExtractor → DeathDataManager → SyncEngine (if in pact)

**Strengths:**
- Dual-signal state machine (combat log + PLAYER_DEAD) reduces false positives
- 3-second suspect window avoids pet/NPC death confusion
- Last 5 attackers ring buffer improves killer attribution
- Hardcore validation via title API + manual flag fallback

**Gaps:**
- **Parser locale:** `IsPlayerDeathMessage` and `ParseKillerFromDeathMessage` use English-only patterns (`"dies"`, `"is slain"`, `"have been slain"`). Non-English clients may miss deaths or killer names.
- **"have been slain"** — Turtle WoW uses "You have been slain by X." — the pattern matches. Verify `ParseKillerFromDeathMessage` with "slain by (.+)" captures correctly when the killer has trailing punctuation.

### 1.2 Blood Pact Creation & Joining

**Flow:** Create → JoinCodeGenerator → PactManager; Join → Serialization → Broadcast JR → any member responds JR2 → joiner receives roster

**Strengths:**
- 8-char alphanumeric join code with validation
- Any pact member can respond to join requests (not just owner)
- JR2 handling ensures non-owner members add new joiners to their roster
- 30-second join timeout with user feedback

**Gaps:**
- No "leave pact" in v1.0 (acknowledged in help text)
- Dormant pact (all dead) prevents new joins — documented but untested in code path

### 1.3 Pact Synchronization

**Flow:** Deaths/roster/dungeons broadcast via addon messages; chunking for large payloads; deduplication; rate limiting

**Strengths:**
- Message types: DA, JR, JR2, SR, RS, DC, DB, CK, OT — comprehensive
- Chunk reassembly with 30s timeout
- Dedup cache (200 entries) prevents duplicate processing
- Rate limiter (0.5s interval) respects WoW addon message limits

**Gaps:**
- When **we** die locally, we broadcast our death but **never update our own pact member record** (isAlive, deathCount, highestLevel). Other members see our death via sync, but our local `pact.members[selfID]` stays stale until we receive… nothing. We never get our own death back. So our local roster shows us as alive until we open the pact tab and it reads from syncedDeaths. Actually — `GetDeathCountForMember` uses syncedDeaths for others and `GetTotalDeaths()` for self. So death count is correct. But `member.isAlive` and `member.highestLevel` for self are wrong until… they're never updated. So the Pact UI could show "alive" for our own card when we're actually dead. **Bug:** When we die locally, we need to update our own `pact.members[selfID]` (isAlive=false, deathCount++, highestLevel from death record).

### 1.4 Ownership Transfer

**Critical Bug:** `BloodPact_OwnershipManager:OnOwnerDeath()` is **never called**. When the pact owner dies:
- The owner records their death locally and broadcasts it
- Other members receive it via OnMemberDeath and mark the owner deceased
- But the owner's client never runs OnOwnerDeath, so:
  - Ownership is never transferred
  - No OT (Ownership Transfer) message is ever sent
  - The pact becomes effectively stranded (owner is dead, no new owner)

**Fix:** Call `BloodPact_OwnershipManager:OnOwnerDeath()` from `DeathDetector:ConfirmAndLogDeath()` after recording the death, when we are in a pact and we are the owner. Before calling, update our own member record (isAlive=false, etc.).

### 1.5 Dungeon Tracking

**Flow:** CHAT_MSG_COMBAT_HOSTILE_DEATH → DungeonTracker parses dead entity → boss lookup → zone verification → DungeonDataManager → broadcast DC

**Strengths:**
- Comprehensive dungeon database (vanilla + Turtle WoW custom)
- Zone verification (GetRealZoneText + GetZoneText) handles locale/alternate names
- First completion only (no duplicates)
- Bulk sync (DB) on login/join

**Gaps:**
- `DungeonTracker:ParseDeadEntityName` uses English patterns (`"dies."`, `"is slain by"`, `"has been slain by"`). Non-English may fail.
- Some multi-boss dungeons only track final boss — by design, acceptable.

### 1.6 UI

**Tabs:** Personal, Pact, Settings

**Strengths:**
- PFUI detection and fallback
- Personal timeline (filter by character)
- Pact timeline (filter by member, color-coded)
- Dungeon detail overlay (click roster card)
- Window position persistence
- Manual hardcore flag in Settings

**Gaps:**
- `arg1` used in scroll handlers (e.g. `DungeonDetailOverlay`, `PactDashboard`) — WoW 1.12 uses `arg1` for OnMouseWheel but it's deprecated in favor of `...` in newer clients. For 1.12 this is fine.
- No keybind for toggle (documented as optional in README)

### 1.7 Export & Wipe

- Export: Not implemented (command prints "not yet implemented")
- Wipe: Works with confirmation; preserves account ID and pact membership

---

## Part 2: Code Review

### 2.1 Architecture

**Strengths:**
- Clear module boundaries (CombatLog, Data, Pact, UI, Utils)
- TOC load order is logical (Utils → Config → Data → CombatLog → Pact → Commands → UI → Core)
- Event-driven with OnUpdate timers for throttled work

**Suggestions:**
- Consider a lightweight "init order" doc so new contributors know dependencies (e.g. AccountIdentity before PactManager).

### 2.2 Serialization.lua

**Bug / Dead Code (line 300):**
```lua
local payload = string.sub(str, pos - (string.len(fields[6] or "") + 1))
```
This line is never used. The return uses `fields[7] or string.sub(str, pos)`. The `pos - ...` calculation is incorrect (would go backwards). Remove the dead line.

**Backward Compatibility:** DA, RS formats handle varying field counts. Good.

### 2.3 DeathDataManager.GetAllPactDeaths

**Potential bug (lines 324–328):**
```lua
local d = death
d.ownerAccountID = ownID
table.insert(allDeaths, d)
```
This mutates the original death record by adding `ownerAccountID`. If the same death is used elsewhere, it could leak. Prefer creating a shallow copy:
```lua
local d = {}
for k, v in pairs(death) do d[k] = v end
d.ownerAccountID = ownID
table.insert(allDeaths, d)
```
Same pattern appears for synced deaths (lines 334–338). Low risk since these are display-only, but worth fixing for cleanliness.

### 2.4 PactManager:OnMemberDeath

When receiving a death for the **owner** (senderID == ownerAccountID), the code marks `member.isAlive = false` but does **not** trigger ownership transfer. That's correct — the owner's client does that when they die. The bug is that the owner's client never calls OnOwnerDeath.

### 2.5 Core.lua Event Handler

**arg1–arg9:** WoW 1.12 populates `arg1`–`arg9` from event args. The handler receives `event` but the inner function uses `arg1`–`arg9` from the outer scope. This is correct for 1.12.

**Error handling:** Debug build wraps OnEvent in pcall and logs errors. Good.

### 2.6 SavedVariablesHandler

**Validation:** Death records validated (characterName, timestamp, level required). Corrupted entries removed. Pact structure validated.

**Config defaults:** `manualHardcoreFlag = true` in ValidateData but `false` in AccountIdentity:Initialize for first launch. Intentional? First-time users get manualHardcoreFlag=false; validated/migrated DBs get true. May want to align.

### 2.7 Dependency Guards

Many modules use `if BloodPact_X then` before calling. Good for resilience when a module fails to load. DungeonTracker, DungeonDataManager, DungeonDetailOverlay are all optional-guarded.

### 2.8 Logger LEVEL.ERROR Check

```lua
if self.currentLevel > self.LEVEL.ERROR then return end
```
This means Error is always shown (ERROR=3, currentLevel would need to be >3, which doesn't exist). So Errors always print. Good.

---

## Part 3: Critical Fixes Required

### Fix 1: Ownership Transfer on Owner Death

**File:** `BloodPact/CombatLog/DeathDetector.lua`

In `ConfirmAndLogDeath`, after `BloodPact_DeathDataManager:RecordDeath(deathRecord)` and before broadcast:

```lua
-- If we're in a pact, update our own member record
if BloodPact_PactManager:IsInPact() then
    local selfID = BloodPact_AccountIdentity:GetAccountID()
    BloodPact_PactManager:UpdateMemberStats(selfID, deathRecord)
    local members = BloodPactAccountDB.pact.members
    if members and members[selfID] then
        members[selfID].isAlive = false
    end
    -- If we're the owner, transfer ownership
    if BloodPact_PactManager:IsOwner() then
        BloodPact_OwnershipManager:OnOwnerDeath()
    end
end
```

Note: `UpdateMemberStats` already increments deathCount and updates highestLevel. We just need to set isAlive=false before calling OnOwnerDeath (since OnOwnerDeath excludes us from the living member search).

### Fix 2: Self Member Update on Local Death

The above snippet covers it — we now call `UpdateMemberStats(selfID, deathRecord)` when we die locally. AddMember is a no-op if already a member; UpdateMemberStats will increment deathCount and update highestLevel. And we set isAlive=false explicitly.

### Fix 3: Serialization DeserializeChunk Dead Code

**File:** `BloodPact/Utils/Serialization.lua`

Remove line 300:
```lua
local payload = string.sub(str, pos - (string.len(fields[6] or "") + 1))
```

---

## Part 4: Recommended Improvements

### Medium Priority

1. **DeathDataManager:GetAllPactDeaths** — Avoid mutating original death records; use shallow copies when adding ownerAccountID.
2. **SavedVariablesHandler manualHardcoreFlag** — Unify default (false vs true) between first launch and validation.
3. **Parser locale** — Add a note in docs or code that combat log parsing is English-only; consider future localization.
4. **DungeonDetailOverlay Initialize** — It creates the panel but the panel is a child of content. The overlay is shown by hiding PactDashboard. Ensure PactDashboard creates before DungeonDetailOverlay:Initialize. TOC order: PactDashboard before DungeonDetailOverlay. PactDashboard:Create registers the panel; DungeonDetailOverlay:Create uses the same content frame. Good.

### Low Priority

5. **README** — Update "Export to JSON is not yet implemented" if that's still accurate.
6. **CommandHandler** — `deletedeath` and `kick` are marked as debug but appear in help. Consider a debug-only section.
7. **Config.lua** — `BLOODPACT_DUNGEON_DATABASE` and `BLOODPACT_DUNGEON_GROUPS` live in DungeonDatabase.lua, not Config. Fine; just noting.
8. **ConflictResolver** — File exists but wasn't deeply reviewed. Appears unused in main flows. Verify it's dead or document its role.

---

## Part 5: Testing Checklist

- [ ] Create pact → join with second account → verify roster sync
- [ ] Owner dies → verify ownership transfers to next-highest living member
- [ ] Last member dies → verify pact becomes dormant
- [ ] Kill final boss in dungeon → verify completion recorded and broadcast
- [ ] `/bp simdeath` → verify full pipeline (serialize → inject → process)
- [ ] `/bp wipe confirm` → verify deaths cleared, pact retained
- [ ] Manual hardcore flag ON → die as non-hardcore char → verify death recorded
- [ ] Chunked message (e.g. large roster sync) → verify reassembly works

---

## Conclusion

Blood Pact is in good shape for a 1.0 addon. The two critical fixes (ownership transfer and self-member update on local death) should be addressed before release. The remaining items are improvements and hardening that can be scheduled for follow-up.
