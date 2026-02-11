# Dungeon Completion Tracking Feature

## Context

BloodPact currently tracks deaths, roster snapshots (level, class, professions, talents), and pact membership. The next feature adds **per-character dungeon completion tracking** — automatically detecting final boss kills and syncing completions across pact members. Clicking a roster card in the Pact Dashboard opens a detail overlay showing that member's dungeon progress.

---

## New Files (4)

### 1. `Data\DungeonDatabase.lua` — Static dungeon definitions

A lookup table of all 34 dungeons (25 vanilla + 9 Turtle WoW custom) with:
- `id` — short unique string key for serialization (e.g. `"deadmines"`, `"sm_cath"`)
- `name` — display name
- `levelMin` / `levelMax`
- `zone` — expected `GetRealZoneText()` value
- `bosses` — array of final boss name strings (for multi-boss dungeons like SM wings)
- `group` — level bracket key for UI grouping

**Dungeon groups** for display:
| Group | Label | Levels |
|-------|-------|--------|
| `low` | Low Level (13-30) | 13-30 |
| `mid` | Mid Level (29-45) | 29-45 |
| `high` | High Level (44-56) | 44-56 |
| `endgame` | Endgame (55-60) | 55-60 |
| `turtlewow` | Turtle WoW | 56-60 |

**Full dungeon list:**

| ID | Name | Boss(es) | Zone | Group |
|----|------|----------|------|-------|
| `ragefire` | Ragefire Chasm | Taragaman the Hungerer | Ragefire Chasm | low |
| `wailing_caverns` | Wailing Caverns | Mutanus the Devourer | Wailing Caverns | low |
| `deadmines` | Deadmines | Edwin VanCleef | The Deadmines | low |
| `sfk` | Shadowfang Keep | Archmage Arugal | Shadowfang Keep | low |
| `bfd` | Blackfathom Deeps | Aku'mai | Blackfathom Deeps | low |
| `stockade` | Stockade | Bazil Thredd | The Stockade | low |
| `gnomeregan` | Gnomeregan | Mekgineer Thermaplugg | Gnomeregan | mid |
| `rfk` | Razorfen Kraul | Charlga Razorflank | Razorfen Kraul | mid |
| `sm_gy` | SM: Graveyard | Bloodmage Thalnos | Scarlet Monastery | mid |
| `sm_lib` | SM: Library | Arcanist Doan | Scarlet Monastery | mid |
| `sm_arm` | SM: Armory | Herod | Scarlet Monastery | mid |
| `sm_cath` | SM: Cathedral | High Inquisitor Whitemane | Scarlet Monastery | mid |
| `rfd` | Razorfen Downs | Amnennar the Coldbringer | Razorfen Downs | mid |
| `uldaman` | Uldaman | Archaedas | Uldaman | mid |
| `zf` | Zul'Farrak | Chief Ukorz Sandscalp | Zul'Farrak | high |
| `mara` | Maraudon | Princess Theradras | Maraudon | high |
| `sunken_temple` | Temple of Atal'Hakkar | Shade of Eranikus | The Temple of Atal'Hakkar | high |
| `brd` | Blackrock Depths | Emperor Dagran Thaurissan | Blackrock Depths | endgame |
| `lbrs` | Lower Blackrock Spire | Overlord Wyrmthalak | Lower Blackrock Spire | endgame |
| `ubrs` | Upper Blackrock Spire | General Drakkisath | Upper Blackrock Spire | endgame |
| `strat_ud` | Stratholme: Undead | Baron Rivendare | Stratholme | endgame |
| `strat_live` | Stratholme: Live | Balnazzar | Stratholme | endgame |
| `scholo` | Scholomance | Darkmaster Gandling | Scholomance | endgame |
| `dm_east` | Dire Maul East | Alzzin the Wildshaper | Dire Maul | endgame |
| `dm_west` | Dire Maul West | Prince Tortheldrin | Dire Maul | endgame |
| `dm_north` | Dire Maul North | King Gordok | Dire Maul | endgame |
| `gilneas` | Gilneas City | Genn Greymane | Gilneas City | turtlewow |
| `karazhan_crypt` | Karazhan Crypt | Alarus | Karazhan Crypt | turtlewow |
| `hateforge` | Hateforge Quarry | Har'gesh Doomcaller | Hateforge Quarry | turtlewow |
| `crescent_grove` | Crescent Grove | Master Raxxieth | Crescent Grove | turtlewow |
| `sw_vault` | Stormwind Vault | Arc'tiras | Stormwind Vault | turtlewow |
| `dragonmaw` | Dragonmaw Retreat | Zuluhed the Whacked | Dragonmaw Retreat | turtlewow |
| `stormwrought` | Stormwrought Ruins | Mergothid | Stormwrought Ruins | turtlewow |

> **Note:** Zone names must be verified in-game via `GetRealZoneText()`. Some Turtle WoW zones may differ from wiki names. Include `altZones` field for fallback matching (e.g. DM wings may return "Capital Gardens" / "Gordok Commons" instead of "Dire Maul" in TW). SM wings all share zone "Scarlet Monastery" but are disambiguated by unique boss names.

### 2. `Data\DungeonDataManager.lua` — CRUD for completions

Follows the `DeathDataManager.lua` pattern.

**Key functions:**
- `RecordCompletion(completion)` — stores in `BloodPactAccountDB.dungeonCompletions[charName][dungeonID] = timestamp`. Only stores first completion per char+dungeon.
- `GetCompletions(charName)` — returns `{ [dungeonID] = timestamp }` for a local character
- `GetAllLocalCompletions()` — returns `{ [charName] = { [dungeonID] = ts } }` for all local chars
- `StoreSyncedCompletion(senderID, data)` — stores a single synced completion from a pact member
- `StoreSyncedCompletions(senderID, completions)` — stores bulk synced completions
- `GetMemberCompletions(accountID)` — returns merged completions for a pact member (own = local data, other = synced data). Returns `{ [dungeonID] = { timestamp = N } }`

**Local storage:**
```lua
BloodPactAccountDB.dungeonCompletions = {
    ["CharName"] = { ["deadmines"] = 1707926400, ["sfk"] = 1708012800 }
}
```

**Pact synced storage:**
```lua
BloodPactAccountDB.pact.syncedDungeonCompletions = {
    [accountID] = { ["deadmines"] = 1707926400, ["gnomeregan"] = 1708012800 }
}
```
> Synced data is flattened to `[dungeonID] = timestamp` (no per-character breakdown for remote members since they only broadcast their main character's completions).

### 3. `CombatLog\DungeonTracker.lua` — Boss kill detection

**Detection algorithm:**
1. `OnCombatDeathMessage(msg)` — called from Core.lua alongside DeathDetector
2. `ParseDeadEntityName(msg)` — extracts dead entity from `"X dies."` or `"X is slain by Y."` patterns
3. Lookup `string.lower(entityName)` in `bossLookup` table (built during `Initialize()` from DungeonDatabase)
4. If found, verify zone: `string.lower(GetRealZoneText())` matches `dungeon.zone` (or `altZones`)
5. If verified: call `DungeonDataManager:RecordCompletion(...)`, print message, broadcast to pact, refresh UI

**Boss lookup** is built once at initialize time: iterates `BLOODPACT_DUNGEON_DATABASE`, maps each `string.lower(bossName)` to its dungeon entry.

### 4. `UI\DungeonDetailOverlay.lua` — Detail overlay for dungeon completions

Follows the `PersonalTimeline.lua` overlay pattern exactly:
- Created in `Initialize()`, fills content area, starts hidden
- Not registered as a tab panel
- `ShowForMember(accountID)` — hides PactDashboard, shows overlay, refreshes
- `Hide()` — hides overlay, re-shows PactDashboard

**Layout:**
```
+----------------------------------------------------------+
| [CharName]'s Dungeon Progress    12 / 34 completed (35%) |
+----------------------------------------------------------+
| --- Low Level (13-30) [4/6] ---                          |
|  v  Ragefire Chasm (13-18)                    2024-01-15 |
|  x  Wailing Caverns (15-25)                          --  |
|  ...                                                      |
| --- Mid Level (29-45) [2/8] ---                          |
|  ...                                                      |
| --- Endgame (55-60) ---                                  |
|  ...                                                      |
| --- Turtle WoW ---                                       |
|  ...                                                      |
+----------------------------------------------------------+
| [Back to Pact]                                            |
+----------------------------------------------------------+
```

- Green "v" + white name for completed, gray "x" + gray name for incomplete
- Completion date right-aligned (or "--")
- Grouped by `BLOODPACT_DUNGEON_GROUPS` with count headers
- Scroll frame for the list

---

## Modified Files (7)

### 1. `BloodPact.toc` — Add 4 new files

Insert in load order:
```
Config.lua
Data\DungeonDatabase.lua          <-- NEW (after Config.lua)
Data\AccountIdentity.lua
...
Data\DeathDataManager.lua
Data\DungeonDataManager.lua       <-- NEW (after DeathDataManager)
CombatLog\DataExtractor.lua
CombatLog\Parser.lua
CombatLog\DeathDetector.lua
CombatLog\DungeonTracker.lua      <-- NEW (after DeathDetector)
...
UI\PactTimeline.lua
UI\DungeonDetailOverlay.lua       <-- NEW (after PactTimeline)
UI\Settings.lua
Core.lua
```

### 2. `Core.lua` — Event routing + initialization

- **Line ~28:** Add `BloodPact_DungeonTracker:Initialize()` after SyncEngine init
- **Line ~35:** Add `BloodPact_DungeonDetailOverlay:Initialize()` after other UI inits
- **Line ~51-52:** Route `CHAT_MSG_COMBAT_HOSTILE_DEATH` to DungeonTracker too:
  ```lua
  BloodPact_DeathDetector:OnCombatDeathMessage(a1)
  BloodPact_DungeonTracker:OnCombatDeathMessage(a1)  -- NEW
  ```
- **Line ~129:** Add `BloodPact_SyncEngine:BroadcastAllDungeonCompletions()` to login sync block

### 3. `Data\SavedVariablesHandler.lua` — Validate new data

- **~Line 31 area:** Add `if not BloodPactAccountDB.dungeonCompletions then BloodPactAccountDB.dungeonCompletions = {} end`
- **~Line 98 area:** Add `if not pact.syncedDungeonCompletions then pact.syncedDungeonCompletions = {} end`

### 4. `Utils\Serialization.lua` — New message types

**DC (Dungeon Completion)** — single real-time announcement:
```
DC~senderID~pactCode~charName~dungeonID~timestamp
```
~55 bytes, fits in a single message.

**DB (Dungeon Bulk)** — full sync on login/join:
```
DB~senderID~pactCode~dungeonID1=ts1,dungeonID2=ts2,...
```
Uses comma-separated `id=timestamp` pairs. Auto-chunked by SyncEngine if >200 bytes.

Add `Serialize`/`Deserialize` functions for both types, following the existing pattern (e.g. `SerializeRosterSnapshot`).

### 5. `Pact\SyncEngine.lua` — New message routing + broadcast

- **OnAddonMessage routing (~line 205):** Add `elseif` for `"DC"` and `"DB"` message types
- **New handler functions:** `HandleDungeonCompletion(msg, sender)` and `HandleDungeonBulk(msg, sender)`
- **New broadcast functions:** `BroadcastDungeonCompletion(completion)` and `BroadcastAllDungeonCompletions()`
- Both follow the existing broadcast pattern (check pact membership, get selfID/pactCode, serialize, queue)

### 6. `Pact\PactManager.lua` — Handle incoming dungeon data + include in sync

- **New handlers:** `OnMemberDungeonCompletion(senderID, data)` and `OnMemberDungeonBulk(senderID, completions)`
- **`OnSyncRequest` (~line 269):** Add `BloodPact_SyncEngine:BroadcastAllDungeonCompletions()`
- **`OnJoinResponse` (~line 171):** Add `BloodPact_SyncEngine:BroadcastAllDungeonCompletions()`

### 7. `UI\PactDashboard.lua` — Clickable roster cards

- **`CreateRosterCard` (~line 234):** Change `CreateFrame("Frame")` to `CreateFrame("Button")` for click support
- Add `OnClick` handler calling `BloodPact_DungeonDetailOverlay:ShowForMember(accountID)`
- Add `OnEnter`/`OnLeave` hover highlight on the card border
- Add "Click for dungeons" hint text at bottom-left of each card

### 8. `UI\MainFrame.lua` — Hide overlay on tab switch

- **`SwitchTab` (~line 212):** Add `BloodPact_DungeonDetailOverlay:Hide()` alongside existing timeline hides

---

## Sync Triggers

| Trigger | Message Type | What's Sent |
|---------|-------------|-------------|
| Boss killed in dungeon | `DC` (single) | One dungeon completion |
| Login (5s delay) | `DB` (bulk) | All local completions |
| Pact join | `DB` (bulk) | All local completions |
| Sync request received | `DB` (bulk) | All local completions |

Backward compatibility: Old clients without dungeon tracking will ignore unknown `DC`/`DB` message types (they fall through the `elseif` chain in `OnAddonMessage`).

---

## Implementation Order

**Phase 1 — Data Foundation (no UI, no sync)**
1. `Data\DungeonDatabase.lua` — full dungeon table
2. `Data\DungeonDataManager.lua` — CRUD for completions
3. `Data\SavedVariablesHandler.lua` — validate new tables
4. `CombatLog\DungeonTracker.lua` — boss kill detection
5. `Core.lua` — event routing + DungeonTracker init
6. `BloodPact.toc` — add new files

**Phase 2 — Pact Sync**
7. `Utils\Serialization.lua` — DC + DB serialize/deserialize
8. `Pact\SyncEngine.lua` — routing + broadcast functions
9. `Pact\PactManager.lua` — handlers + sync triggers

**Phase 3 — UI**
10. `UI\DungeonDetailOverlay.lua` — full overlay
11. `UI\PactDashboard.lua` — clickable roster cards
12. `UI\MainFrame.lua` — hide overlay on tab switch
13. `Core.lua` — DungeonDetailOverlay init

---

## Verification

1. **Boss detection:** Enter a dungeon, kill the final boss. Run `/script DEFAULT_CHAT_FRAME:AddMessage(BloodPactAccountDB.dungeonCompletions["YourCharName"]["deadmines"] or "nil")` to verify the timestamp was stored.
2. **Pact sync:** Have two pact members online. Kill a boss on one — verify the other receives the `DC` message and stores it in `syncedDungeonCompletions`.
3. **Bulk sync:** Log out and back in. Verify `DB` message sent and received by pact members.
4. **UI overlay:** Open Blood Pact panel > Pact tab > click a roster card > verify dungeon overlay appears with correct completion data and grouping. Click "Back to Pact" to return.
5. **Zone name verification:** Test in-game that `GetRealZoneText()` returns the expected zone name for each dungeon. Update `DungeonDatabase.lua` if any mismatches.

---

## Key Reusable Patterns & Files

- **Overlay pattern:** `UI\PersonalTimeline.lua` — exact template for DungeonDetailOverlay structure
- **Data manager pattern:** `Data\DeathDataManager.lua` — template for DungeonDataManager
- **Serialization pattern:** `Utils\Serialization.lua` lines 96-195 (DA) and 314-389 (RS)
- **Sync broadcast pattern:** `Pact\SyncEngine.lua` lines 37-81
- **UI helpers:** `UI\PFUIStyles.lua` — `BP_ApplyPanelBackdrop`, `BP_CreateFontString`, `BP_CreateButton`, `BP_CreateDivider`, `BP_Color`
- **Colors:** `Config.lua` — `BLOODPACT_COLORS`, `BLOODPACT_CLASS_COLORS`
