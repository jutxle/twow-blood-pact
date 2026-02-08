# Blood Pact

A hardcore death tracker addon for **Turtle WoW** (WoW 1.12). Record every permadeath, form Blood Pacts with other hardcore players, and share your deaths across the group in real time.

---

## Features

- **Automatic death detection** — combat log and `PLAYER_DEAD` event state machine captures kills, including attacker name, level, zone, and sub-zone
- **Rich death records** — stores character name, level, class, race, total XP, gold lost, rare+ items lost, killer info, and timestamps
- **Personal timeline** — scrollable history of every death across all your characters, filterable per character
- **Blood Pact groups** — create a shared pact with an 8-character join code; friends join with `/bloodpact join <code>`
- **Pact sync** — deaths broadcast over GUILD/RAID/PARTY channels to all online pact members; offline members receive a catch-up sync on login
- **Pact dashboard** — aggregate stats (total deaths, member count, highest level reached, gold lost) and member roster with alive/deceased status
- **Pact timeline** — unified scrollable history of all member deaths with per-player color coding
- **PFUI compatible** — detects pfUI and uses its fonts/styles; falls back gracefully to default WoW UI if pfUI is absent
- **Manual hardcore flag** — for players without the "Still Alive" title detection, a manual checkbox is provided in Settings

---

## Requirements

- **Turtle WoW** client (WoW 1.12.1 / Interface 11200)
- Optional: [pfUI](https://github.com/shagu/pfUI) for styled fonts and backdrops

---

## Installation

1. Copy the `BloodPact/` folder into your addons directory:
   ```
   TurtleWoW\Interface\AddOns\BloodPact\
   ```
2. Launch the game and enable **Blood Pact** in the AddOns list on the character select screen.

### Deploy Script (Windows)

If you have the repository cloned, run from the project root:
```powershell
.\deploy.ps1
```
This copies `BloodPact/` directly to `C:\Users\<you>\Games\TurtleWoW\Interface\AddOns\BloodPact`.

---

## Slash Commands

| Command | Description |
|---|---|
| `/bloodpact` | Open the Blood Pact window |
| `/bloodpact show` | Open the window |
| `/bloodpact hide` | Close the window |
| `/bloodpact toggle` | Toggle window visibility |
| `/bloodpact create <name>` | Create a new Blood Pact with the given name |
| `/bloodpact join <code>` | Join a Blood Pact using an 8-character code |
| `/bloodpact wipe` | Show wipe confirmation prompt |
| `/bloodpact wipe confirm` | Permanently delete all death records (account ID and pact membership are preserved) |
| `/bloodpact help` | Show command list |
| `/bp` | Shortcut for `/bloodpact` |

---

## How It Works

### Death Detection

Deaths are detected through a two-signal state machine:

1. **SUSPECTED** — A `CHAT_MSG_COMBAT_HOSTILE_DEATH` message containing the player's name is seen, or `PLAYER_DEAD` fires directly (environmental death).
2. **COLLECTING** — `PLAYER_DEAD` confirms the death within a 3-second window; character state is captured (level, XP, gold, inventory, location).
3. **COMPLETE** — The death record is saved locally and broadcast to any online pact members.

The last 5 attackers seen in the combat log are tracked in a ring buffer so the killer is known even if the death message doesn't name them directly.

### Blood Pacts

- One player creates a pact with `/bloodpact create <name>`. A random 8-character alphanumeric join code is generated.
- Other players join with `/bloodpact join <code>`. The addon sends a join request over all available channels; any online pact member responds with the current member roster.
- Deaths are broadcast as addon messages (prefix `BLDPCT`) over GUILD, RAID, or PARTY channels, whichever are active. Messages larger than 200 bytes are chunked automatically.
- On login, if you are in a pact, a sync request is sent after 5 seconds to catch up on any deaths that happened while you were offline.

### Data Storage

All data is stored in the **account-wide** `BloodPactAccountDB` SavedVariable:

```
BloodPactAccountDB
├── accountID           -- stable identifier derived from first character name
├── accountCreatedTimestamp
├── schemaVersion
├── config
│   ├── manualHardcoreFlag
│   └── windowPosition  {x, y}
├── deaths              -- keyed by character name, array of death records (max 25 each)
└── pact
    ├── pactName
    ├── joinCode
    ├── ownerAccountID
    ├── members         -- keyed by accountID
    └── memberDeaths    -- synced deaths from other pact members
```

Death records are capped at **25 per character** (oldest pruned first).

---

## UI Overview

The main window has three tabs:

**Personal** — Your own characters' death stats. Shows total deaths, highest level reached, total gold lost, and total XP lost across all characters. Below that, a character list with a "Timeline" button for each. The timeline shows every death with full detail.

**Pact** — Pact-level aggregate stats and the member roster. Each member shows their alive/deceased status, highest level, and death count. A "Pact Timeline" button opens a unified view of all member deaths, filterable by member.

**Settings** — Your account ID and creation date, the manual hardcore flag toggle, pact creation/join shortcuts, and a data wipe button.

---

## Technical Notes

- Built for **WoW 1.12 API** (no `C_Timer`, no `...` varargs in event handlers, `table.getn()` throughout)
- Event handler arguments use `arg1`–`arg9` globals
- Addon message prefix: `BLDPCT` (6 characters)
- All timers use `OnUpdate` accumulators
- Serialization is pipe-delimited fixed-field encoding with escape sequences for special characters

---

## Version

**1.0.0** — Initial release. Export to JSON is not yet implemented.
