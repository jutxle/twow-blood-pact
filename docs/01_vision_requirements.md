# Blood Pact - Vision & Requirements Document
**Version:** 1.0  
**Date:** February 7, 2026  
**Author:** Justin  
**Target Platform:** Turtle WoW (Classic WoW 1.12 Fork)

---

## Executive Summary

Blood Pact is a hardcore death tracking addon for Turtle WoW that creates a permanent memorial to every fallen hardcore character. The addon provides individual players with comprehensive analytics of their hardcore journey while enabling friend groups to form "Blood Pacts" - shared communities that track collective death statistics across all members.

The addon transforms the hardcore death experience from a solitary frustration into a shared journey with meaningful data persistence, creating a rich historical record of a player's hardcore attempts and their community's collective struggles.

### Core Value Proposition
- **Individual Accountability:** Never forget a death - comprehensive tracking of when, where, and how each hardcore character fell
- **Community Bonding:** Share the hardcore journey with friends through synchronized death statistics
- **Historical Context:** Timeline visualization showing the full arc of hardcore attempts over time
- **Data Portability:** JSON export enables external analysis and long-term preservation

---

## Product Vision

### Mission Statement
To honor every hardcore death by creating permanent, detailed records that transform individual tragedy into collective memory and community bonding.

### Target Audience
- **Primary:** Hardcore WoW Classic players on Turtle WoW who play with friend groups
- **Secondary:** Solo hardcore players interested in comprehensive personal analytics
- **Tertiary:** Hardcore streamers and content creators seeking death statistics for content

### Success Criteria
1. **Adoption:** 500+ active installations within 3 months of launch
2. **Data Integrity:** 99%+ accuracy in death detection (no false positives/negatives)
3. **Usability:** Users can create/join pacts within 30 seconds
4. **Performance:** No perceivable FPS impact during regular gameplay
5. **Reliability:** Zero data corruption incidents in production

---

## User Stories & Use Cases

### Phase 1: Individual Analytics

#### User Story 1.1: First Death Tracking
**As a** hardcore player who just died for the first time,  
**I want** the addon to automatically capture all details of my death,  
**So that** I have a permanent record of my first hardcore attempt without manual intervention.

**Acceptance Criteria:**
- Combat log parsing detects death event within 1 second
- Character name, level, total XP, timestamp captured
- Death location (zone, coordinates) recorded
- Killer entity (NPC name, level) or environmental cause identified
- All equipped rare+ quality items inventoried
- Currency amount (gold/silver/copper) recorded
- Data persists to SavedVariables immediately
- Only characters with "Still Alive" title are tracked

#### User Story 1.2: Death Review
**As a** player reviewing my hardcore history,  
**I want** to see a chronological list of all my character deaths,  
**So that** I can analyze patterns and learn from past mistakes.

**Acceptance Criteria:**
- All deaths visible in timeline UI
- Deaths sorted by timestamp (most recent first)
- Each death shows: character name, level, killer, location, date/time
- Deaths limited to most recent 25 per character
- UI clearly indicates which character each death belongs to

#### User Story 1.3: Account Identity
**As a** first-time addon user,  
**I want** the addon to assign my account a unique identifier,  
**So that** my death data is associated with my account across all characters.

**Acceptance Criteria:**
- On first launch, account ID = first character name launching addon
- Account ID stored in account-wide SavedVariables
- Account ID displayed in UI settings/info panel
- Account ID never changes after initial assignment
- All character deaths linked to this account ID

### Phase 2: Grouping (Blood Pacts)

#### User Story 2.1: Pact Creation
**As a** hardcore guild member,  
**I want** to create a Blood Pact and invite friends,  
**So that** we can track our collective hardcore journey together.

**Acceptance Criteria:**
- Pact creator names the pact (1-32 characters)
- System generates unique 8-character alphanumeric join code
- Join code displayed prominently in UI
- Creator can copy join code via button/command
- Pact persists even if creator's character dies
- Pact ownership transfers to member with highest-level living character on owner death

#### User Story 2.2: Pact Joining
**As a** player invited to a Blood Pact,  
**I want** to enter a join code and immediately see group statistics,  
**So that** I can be part of my friends' hardcore community.

**Acceptance Criteria:**
- Join code input available via UI or `/bloodpact join CODE` command
- Invalid codes display clear error message
- Valid codes add player to pact within 5 seconds
- Existing pact data syncs to new member within 30 seconds
- New member's death history shared with existing members
- Player can only be in one pact at a time (v1.0 constraint)

#### User Story 2.3: Pact Data Synchronization
**As a** pact member,  
**I want** to see when other members die in near real-time,  
**So that** I can react and engage with the community around the event.

**Acceptance Criteria:**
- Death events broadcast to all online pact members within 10 seconds
- Offline members receive death updates on next login
- All death details visible to all pact members (full transparency)
- No data conflicts if multiple members die simultaneously
- Pact timeline updates automatically without UI refresh needed

#### User Story 2.4: Persistent Membership
**As a** dead hardcore character in a pact,  
**I want** my death to remain in pact history forever,  
**So that** my character is memorialized in the group's collective story.

**Acceptance Criteria:**
- Dead characters remain listed in pact roster (marked as deceased)
- Dead character deaths permanently visible in pact timeline
- Dead characters do not count toward "active members" statistic
- Dead character's player can view pact data from any of their characters
- No mechanism to remove deaths from pact history

### Phase 3: Individual User Interface

#### User Story 3.1: Statistics Dashboard
**As a** hardcore player,  
**I want** a visual dashboard of my account's hardcore statistics,  
**So that** I can quickly understand my overall hardcore performance.

**Acceptance Criteria:**
- Total deaths displayed prominently
- Highest level achieved across all characters shown
- Total gold lost calculated and displayed
- Total XP lost calculated and displayed
- Average character lifespan (time played before death)
- UI styled to match PFUI aesthetic
- Dashboard accessible via `/bloodpact show` or keybind

#### User Story 3.2: Personal Timeline
**As a** player reflecting on my hardcore journey,  
**I want** a timeline visualization of my character progression,  
**So that** I can see the story arc of my attempts over time.

**Acceptance Criteria:**
- Chronological timeline from earliest to most recent activity
- Death events marked with red indicators
- Level milestones (10, 20, 30, 40, 50, 60) marked with icons
- Timestamps in server time (readable date format)
- Tooltip on hover shows full death details
- Timeline scrollable/zoomable for long histories
- Visual separation between different characters

### Phase 4: Group Interface

#### User Story 4.1: Pact Overview
**As a** pact member,  
**I want** to see aggregate statistics for our entire pact,  
**So that** I understand our collective hardcore experience.

**Acceptance Criteria:**
- Total pact deaths displayed
- Total members (living + deceased) shown
- Highest level achieved by any pact member
- Total gold lost by entire pact
- Current active members listed with their highest character level
- Memorial section listing all fallen characters
- Pact name displayed as header

#### User Story 4.2: Pact Timeline
**As a** pact member,  
**I want** to see a shared timeline of all pact member deaths,  
**So that** I can experience our collective hardcore story.

**Acceptance Criteria:**
- Unified timeline showing all member deaths chronologically
- Each death labeled with character name and player account
- Color-coding or icons distinguish between different players
- Level milestones shown for each character
- Able to filter timeline by specific member
- Pact creation date marked on timeline
- Timeline updates dynamically as new deaths occur

### Cross-Cutting User Stories

#### User Story 5.1: Data Export
**As a** hardcore player who wants to preserve my data,  
**I want** to export my death records to JSON,  
**So that** I can analyze it externally or keep permanent backups.

**Acceptance Criteria:**
- `/bloodpact export personal` exports account's death data
- `/bloodpact export pact` exports entire pact history (if in pact)
- JSON file created in WoW directory with timestamp
- Export includes all captured death metadata
- JSON is valid and human-readable
- Success/failure message displayed to user

#### User Story 5.2: Data Management
**As a** player starting fresh or troubleshooting,  
**I want** to wipe my addon data,  
**So that** I can reset my statistics or clear corrupted data.

**Acceptance Criteria:**
- `/bloodpact wipe` command deletes all local death data
- Confirmation prompt prevents accidental wipes
- Account ID is NOT deleted (persists through wipes)
- Pact membership information retained
- UI updates immediately after wipe
- Wipe operation logged for user confirmation

#### User Story 5.3: Performance
**As a** player in combat,  
**I want** the addon to have zero gameplay impact,  
**So that** my hardcore character doesn't die due to addon lag.

**Acceptance Criteria:**
- Combat log parsing uses throttled event handlers
- SavedVariables writes batched (not per-event)
- UI elements hidden during combat (unless death occurs)
- Memory usage < 5MB for typical use cases
- No FPS drops measurable by player
- Addon communication messages rate-limited

---

## Functional Requirements

### FR1: Death Detection & Logging

**FR1.1:** The addon MUST detect hardcore character deaths by cross-referencing `UNIT_DIED` and `PLAYER_DEAD` combat log events.

**FR1.2:** The addon MUST validate hardcore status by checking for the "Still Alive" player title before logging any death.

**FR1.3:** The addon MUST NOT track or log any data for softcore characters (characters without "Still Alive" title).

**FR1.4:** On death detection, the addon MUST capture:
- Character name (string)
- Character level (integer 1-60)
- Total experience points (integer)
- Timestamp in server time (ISO 8601 format preferred, fallback to WoW date/time)
- Zone name (string)
- Subzone name if available (string)
- Map coordinates (X, Y as floats 0.0-1.0)
- Killer entity name (string)
- Killer entity level (integer)
- Killer entity type (NPC, environmental, unknown)
- All equipped items of rare (blue) or higher quality with:
  - Item name
  - Item ID
  - Item quality
  - Equipment slot
- Currency in copper (converts to gold/silver/copper for display)

**FR1.5:** The addon MUST log death data to SavedVariables within 5 seconds of detection to minimize data loss risk.

**FR1.6:** The addon MUST limit death history to the most recent 25 deaths per character to prevent unbounded data growth.

**FR1.7:** When the 26th death is recorded for a character, the addon MUST delete the oldest death record for that character.

### FR2: Account Identity

**FR2.1:** On first launch of the addon by any character, the addon MUST generate an account identifier using the launching character's name.

**FR2.2:** The account identifier MUST be stored in account-wide SavedVariables.

**FR2.3:** The account identifier MUST persist through all addon operations except explicit data wipe.

**FR2.4:** The account identifier MUST be displayed to the user in the UI settings panel.

**FR2.5:** All death records MUST be associated with the account identifier, not individual characters.

### FR3: Blood Pact Creation

**FR3.1:** A player MUST be able to create a Blood Pact with a custom name between 1 and 32 characters.

**FR3.2:** On pact creation, the addon MUST generate a unique 8-character alphanumeric join code (case-insensitive).

**FR3.3:** The join code MUST be collision-resistant (probability of duplicate codes < 0.001% with 10,000 active pacts).

**FR3.4:** The pact creator MUST be designated as the pact owner in metadata.

**FR3.5:** The pact MUST store:
- Pact name
- Join code
- Owner account ID
- Creation timestamp
- Member list (array of account IDs)

**FR3.6:** The pact join code MUST be displayed in the UI and copyable via command.

### FR4: Blood Pact Joining

**FR4.1:** A player MUST be able to join a pact by entering an 8-character join code via UI or `/bloodpact join CODE` command.

**FR4.2:** The addon MUST validate the join code format before attempting synchronization.

**FR4.3:** On invalid join code entry, the addon MUST display error: "Invalid join code format. Codes are 8 characters (letters and numbers)."

**FR4.4:** On successful join, the addon MUST:
- Add player's account ID to pact member list
- Sync existing pact death data to new member
- Broadcast new member's death history to existing pact members
- Display success message with pact name

**FR4.5:** A player MUST only be able to join one pact at a time (v1.0 constraint).

**FR4.6:** If a player attempts to join a second pact, the addon MUST display error: "You are already in a Blood Pact. Leave your current pact first."

### FR5: Blood Pact Synchronization

**FR5.1:** Death events MUST be broadcast to all online pact members via addon communication channel within 10 seconds.

**FR5.2:** Offline pact members MUST receive death updates on their next login through data reconciliation.

**FR5.3:** The addon MUST use version vectors or timestamps to resolve synchronization conflicts.

**FR5.4:** On synchronization conflict, the addon MUST prefer the death record with the earlier timestamp.

**FR5.5:** The addon MUST rate-limit addon communication messages to prevent chat throttling (max 10 messages per 5 seconds).

**FR5.6:** Large data syncs (e.g., new member joining) MUST be chunked into multiple messages to respect WoW 1.12 addon message size limits (255 bytes per message).

### FR6: Pact Ownership Transfer

**FR6.1:** When the pact owner's highest-level character dies, the addon MUST transfer pact ownership to the pact member with the highest-level living character.

**FR6.2:** If multiple members are tied for highest level, the addon MUST transfer ownership to the member who has been in the pact longest.

**FR6.3:** Ownership transfer MUST be broadcast to all pact members with a notification message.

**FR6.4:** If the last living character in a pact dies, the pact MUST become "dormant" with no owner (all members deceased).

**FR6.5:** A dormant pact MUST remain accessible (read-only) but prevent new members from joining.

### FR7: Individual User Interface

**FR7.1:** The addon MUST provide a standalone UI window styled to match PFUI aesthetics.

**FR7.2:** The UI MUST be toggleable via `/bloodpact show` or `/bloodpact toggle` commands.

**FR7.3:** The UI MUST display at minimum:
- Total account deaths
- Highest level achieved
- Total gold lost
- Total XP lost
- List of all characters with death counts

**FR7.4:** The UI MUST include a timeline view showing:
- Chronological death events
- Level milestone markers (10, 20, 30, 40, 50, 60)
- Server timestamp for each event
- Visual indicators distinguishing deaths from milestones

**FR7.5:** Timeline tooltips on hover MUST display full death details including location, killer, and loot lost.

**FR7.6:** The UI MUST allow switching between personal and pact views if the player is in a pact.

### FR8: Pact User Interface

**FR8.1:** When in a pact, the UI MUST display pact-level statistics:
- Pact name
- Total pact deaths
- Total members (living + deceased)
- Highest level achieved by any member
- Total gold lost by all members
- Join code (for pact owner/sharing)

**FR8.2:** The pact UI MUST include a roster showing:
- All member account IDs
- Each member's highest-level character (living or deceased)
- Death count per member
- Visual indicator for deceased vs. living members

**FR8.3:** The pact timeline MUST display all member deaths chronologically with:
- Character name and player account ID
- Level, location, killer
- Timestamp
- Color-coding or icons per player for visual distinction

**FR8.4:** The pact UI MUST allow filtering timeline by specific member.

### FR9: Data Export

**FR9.1:** The addon MUST provide `/bloodpact export personal` command to export account death data.

**FR9.2:** The addon MUST provide `/bloodpact export pact` command to export entire pact data (only if in a pact).

**FR9.3:** Exported data MUST be valid JSON format.

**FR9.4:** JSON export MUST include:
- Account identifier
- All death records with full metadata
- Character information
- Timestamps in ISO 8601 or WoW-readable format
- Pact information if exporting pact data

**FR9.5:** The addon MUST write JSON export to `WTF/Account/<AccountName>/SavedVariables/BloodPact_Export_<timestamp>.json`.

**FR9.6:** On successful export, the addon MUST display message with file path.

### FR10: Data Management

**FR10.1:** The addon MUST provide `/bloodpact wipe` command to delete all death data.

**FR10.2:** The wipe command MUST prompt user for confirmation: "Type /bloodpact wipe confirm to permanently delete all death data."

**FR10.3:** On confirmed wipe, the addon MUST:
- Delete all death records
- Preserve account identifier
- Preserve pact membership information
- Clear UI displays
- Display confirmation message

**FR10.4:** The addon MUST NOT automatically delete or prune data except when exceeding per-character death limit (25 deaths).

---

## Non-Functional Requirements

### NFR1: Performance

**NFR1.1:** Combat log parsing MUST use event throttling to prevent FPS drops during intense combat.

**NFR1.2:** SavedVariables writes MUST be batched and executed during safe periods (out of combat, on logout).

**NFR1.3:** UI rendering MUST not cause frame rate drops exceeding 5ms per frame.

**NFR1.4:** Memory usage MUST stay under 10MB for accounts with full death history (25 deaths per character).

**NFR1.5:** Addon communication messages MUST be rate-limited to prevent throttling by WoW client.

### NFR2: Reliability

**NFR2.1:** Death detection MUST have 99%+ accuracy (false positive/negative rate < 1%).

**NFR2.2:** SavedVariables MUST be protected against corruption through validation on load.

**NFR2.3:** The addon MUST gracefully handle corrupted data by:
- Logging error to default chat frame
- Isolating corrupted records
- Allowing addon to continue functioning with partial data

**NFR2.4:** Addon communication MUST handle packet loss and retry failed synchronizations.

### NFR3: Compatibility

**NFR3.1:** The addon MUST be compatible with Turtle WoW (WoW 1.12 client).

**NFR3.2:** The addon MUST use only WoW 1.12 API functions (no retail or private server-specific APIs).

**NFR3.3:** The addon MUST be written in Lua 5.1 syntax.

**NFR3.4:** The addon MUST assume PFUI is installed for UI styling references.

**NFR3.5:** The addon MUST NOT conflict with common hardcore addons (HC, Turtle Hardcore, etc.).

### NFR4: Usability

**NFR4.1:** Creating or joining a pact MUST be completable within 30 seconds by an average player.

**NFR4.2:** All error messages MUST be clear and actionable (state what went wrong and how to fix it).

**NFR4.3:** The UI MUST be navigable without referring to documentation for common tasks.

**NFR4.4:** Slash commands MUST have helpful text via `/bloodpact help`.

### NFR5: Scalability

**NFR5.1:** The addon MUST support pacts with up to 40 members (full raid size) without performance degradation.

**NFR5.2:** The addon MUST handle up to 1,000 total death records across all pact members.

**NFR5.3:** Timeline rendering MUST remain performant with 100+ visible events.

### NFR6: Security & Privacy

**NFR6.1:** The addon MUST NOT transmit any data outside the WoW client (no external APIs).

**NFR6.2:** Pact join codes MUST be sufficiently random to prevent brute-force guessing.

**NFR6.3:** The addon MUST NOT expose player account identifiers to addon communication channels (use hashed IDs if needed).

---

## Out of Scope (Future Versions)

The following features are explicitly out of scope for v1.0:

1. **Multiple pact membership** - Players joining more than one pact simultaneously
2. **Pact leaving/disbanding** - Mechanics to exit or destroy a pact
3. **Privacy controls** - Hiding specific deaths or statistics from pact members
4. **Level milestones tracking** - Detailed logging of when characters hit specific levels
5. **Softcore character tracking** - Any tracking of non-hardcore characters
6. **Death cause analytics** - Aggregated "most common causes of death" statistics
7. **In-game achievements** - "First to 60", "Most gold lost", etc.
8. **Web integration** - Uploading data to external websites
9. **Death notifications** - In-game alerts when pact members die (could be Phase 5)
10. **Cross-server pacts** - Coordinating pacts across different WoW servers
11. **Suggested additions** - Death stories, streaks, comparative stats, memorial mode, etc. (deferred to post-1.0)

---

## Acceptance Criteria Summary

### Phase 1 Completion Criteria
- [ ] Hardcore deaths detected via combat log with 99%+ accuracy
- [ ] All specified metadata captured and stored
- [ ] Account identifier generated on first launch
- [ ] 25-death-per-character limit enforced
- [ ] Zero performance impact measurable by players

### Phase 2 Completion Criteria
- [ ] Pact creation generates unique join code
- [ ] Players can join pacts via code entry
- [ ] Death data syncs between pact members within 30 seconds
- [ ] Pact ownership transfers correctly on owner death
- [ ] Dead characters remain in pact permanently

### Phase 3 Completion Criteria
- [ ] Individual UI displays all required statistics
- [ ] Timeline visualizes deaths and level milestones chronologically
- [ ] UI matches PFUI styling conventions
- [ ] UI accessible via slash command and optional keybind

### Phase 4 Completion Criteria
- [ ] Pact UI displays aggregate statistics
- [ ] Pact timeline shows all member deaths
- [ ] Members can filter timeline by player
- [ ] UI distinguishes between living and deceased members

### Overall Product Completion Criteria
- [ ] JSON export functions correctly for personal and pact data
- [ ] Data wipe command works with confirmation
- [ ] All slash commands documented in `/bloodpact help`
- [ ] No known critical or high-priority bugs
- [ ] User testing confirms 30-second pact join time
- [ ] Performance testing confirms <5MB memory usage baseline

---

## Glossary

- **Hardcore Character:** A WoW character with the "Still Alive" title, indicating permadeath ruleset
- **Softcore Character:** A normal WoW character without permadeath restrictions
- **Blood Pact:** A named group of players sharing hardcore death statistics
- **Pact Owner:** The player who created a Blood Pact, with administrative privileges
- **Join Code:** 8-character alphanumeric identifier used to join a specific Blood Pact
- **Death Record:** Complete metadata captured when a hardcore character dies
- **Account Identifier:** Unique ID for a player's WoW account, derived from first character name
- **SavedVariables:** WoW addon data persistence mechanism stored in WTF folder
- **PFUI:** A popular WoW 1.12 UI overhaul addon that Blood Pact's UI will match stylistically
- **Turtle WoW:** A Classic WoW 1.12 private server with custom content
- **Combat Log Parsing:** Reading and interpreting WoW combat events to detect deaths
- **Timeline:** Chronological visualization of character progression and death events

---

## Approval & Sign-Off

**Document Owner:** Justin  
**Status:** Draft v1.0  
**Next Review Date:** Upon completion of Technical Design Document

This Vision & Requirements Document serves as the authoritative source for what Blood Pact will deliver in version 1.0. Any deviations must be documented and approved through change control process.
