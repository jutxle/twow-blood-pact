# Blood Pact - UI/UX Specification Document
**Version:** 1.0  
**Date:** February 7, 2026  
**Author:** Justin  
**Target Platform:** Turtle WoW (WoW 1.12 Client, PFUI-styled)

---

## Table of Contents
1. [Design Philosophy](#design-philosophy)
2. [PFUI Style Integration](#pfui-style-integration)
3. [Main UI Window](#main-ui-window)
4. [Personal Dashboard View](#personal-dashboard-view)
5. [Personal Timeline View](#personal-timeline-view)
6. [Pact Dashboard View](#pact-dashboard-view)
7. [Pact Timeline View](#pact-timeline-view)
8. [Pact Creation/Join Flow](#pact-creationjoin-flow)
9. [Settings Panel](#settings-panel)
10. [Slash Commands](#slash-commands)
11. [User Flows](#user-flows)
12. [Accessibility](#accessibility)
13. [Responsive Design](#responsive-design)

---

## Design Philosophy

### Core Principles

1. **Memorial First** - UI should honor the significance of hardcore deaths, treating each as a meaningful event
2. **Clarity Over Complexity** - Information dense but organized, avoiding clutter
3. **PFUI Native Feel** - Seamlessly integrate with existing PFUI aesthetic
4. **Fast Access** - Critical information visible within 1 click/command
5. **Non-Intrusive** - No auto-popups, player controls when to view data

### Design Goals

- **Intuitive Navigation** - Users understand UI structure within 30 seconds
- **Emotional Resonance** - Visual design reflects gravity of permadeath
- **Data Transparency** - All captured data visible, nothing hidden
- **Performance** - Smooth 60 FPS even with full death histories

### Color Palette (Aligned with PFUI)

```
Primary Colors:
- Background: #1a1a1a (Dark Gray - PFUI backdrop)
- Panel: #2a2a2a (Slightly lighter gray)
- Border: #3a3a3a (Subtle border)

Accent Colors:
- Death Red: #8b0000 (Dark red for death events)
- Milestone Gold: #ffd700 (Gold for level milestones)
- Pact Blue: #4169e1 (Royal blue for pact elements)
- Status Green: #00ff00 (Bright green for alive status)

Text Colors:
- Primary Text: #ffffff (White)
- Secondary Text: #cccccc (Light gray)
- Disabled Text: #666666 (Medium gray)
- Error Text: #ff4444 (Bright red)
- Success Text: #44ff44 (Bright green)

Quality Colors (WoW Standard):
- Common: #ffffff
- Uncommon: #1eff00
- Rare: #0070dd
- Epic: #a335ee
- Legendary: #ff8000
```

---

## PFUI Style Integration

### Font Standards

PFUI uses custom fonts for consistency. Blood Pact should match.

```lua
-- Font references from PFUI
local FONT_FAMILY = "Interface\\AddOns\\pfUI\\fonts\\homespun.ttf"
local FONT_SIZE_LARGE = 16
local FONT_SIZE_MEDIUM = 12
local FONT_SIZE_SMALL = 10

-- Font flag: OUTLINE makes text crisp at small sizes
local FONT_FLAGS = "OUTLINE"

-- Apply to text elements
myFontString:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, FONT_FLAGS)
```

### Texture Standards

```lua
-- PFUI backdrop textures
local BACKDROP_TEXTURE = "Interface\\AddOns\\pfUI\\img\\panel"
local BORDER_TEXTURE = "Interface\\AddOns\\pfUI\\img\\border"

-- Standard backdrop template
local pfuiBackdrop = {
    bgFile = BACKDROP_TEXTURE,
    edgeFile = BORDER_TEXTURE,
    tile = false,
    tileSize = 8,
    edgeSize = 8,
    insets = {left = 3, right = 3, top = 3, bottom = 3}
}

-- Apply to frames
myFrame:SetBackdrop(pfuiBackdrop)
myFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9) -- Dark gray, slight transparency
myFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) -- Gray border
```

### Button Standards

```lua
-- PFUI-style button appearance
function CreatePFUIButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    
    -- Backdrop
    button:SetBackdrop({
        bgFile = "Interface\\AddOns\\pfUI\\img\\panel",
        edgeFile = "Interface\\AddOns\\pfUI\\img\\border",
        tile = false,
        edgeSize = 8,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    button:SetBackdropColor(0.2, 0.2, 0.2, 1)
    button:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    -- Text
    local buttonText = button:CreateFontString(nil, "OVERLAY")
    buttonText:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
    buttonText:SetText(text)
    buttonText:SetPoint("CENTER")
    button.text = buttonText
    
    -- Hover effect
    button:SetScript("OnEnter", function()
        button:SetBackdropColor(0.3, 0.3, 0.3, 1)
    end)
    
    button:SetScript("OnLeave", function()
        button:SetBackdropColor(0.2, 0.2, 0.2, 1)
    end)
    
    return button
end
```

---

## Main UI Window

### Window Specifications

```
Dimensions:
- Width: 600px
- Height: 450px
- Minimum Width: 500px (resizable)
- Minimum Height: 400px (resizable)

Position:
- Default: Center screen
- Remember last position in SavedVariables

States:
- Shown/Hidden (toggled via /bloodpact toggle)
- Locked/Unlocked (draggable title bar)
```

### Window Structure (Text Wireframe)

```
┌─────────────────────────────────────────────────────────────┐
│ Blood Pact                                    [Close] [Size] │ <- Title Bar
├─────────────────────────────────────────────────────────────┤
│ [Personal] [Pact] [Settings]                                │ <- Tab Bar
├─────────────────────────────────────────────────────────────┤
│                                                               │
│                    CONTENT AREA                              │
│             (Switches based on active tab)                   │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│ Account ID: MyFirstCharacter    |    Blood Pact v1.0        │ <- Status Bar
└─────────────────────────────────────────────────────────────┘
```

### Title Bar

```lua
-- Title bar appearance
titleBar:SetHeight(24)
titleBar:SetBackdropColor(0.15, 0.15, 0.15, 1) -- Darker than body

-- Title text
local titleText = titleBar:CreateFontString(nil, "OVERLAY")
titleText:SetFont(FONT_FAMILY, FONT_SIZE_LARGE, "OUTLINE")
titleText:SetText("Blood Pact")
titleText:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
titleText:SetTextColor(1, 1, 1, 1)

-- Close button
local closeButton = CreateFrame("Button", nil, titleBar)
closeButton:SetWidth(18)
closeButton:SetHeight(18)
closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
-- Add X texture or text
```

### Tab Bar

```lua
-- Tab appearance
local tabWidth = 100
local tabHeight = 26

-- Inactive tab colors
inactiveTab:SetBackdropColor(0.2, 0.2, 0.2, 1)

-- Active tab colors
activeTab:SetBackdropColor(0.3, 0.3, 0.3, 1)
activeTab:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
```

**Tab Labels:**
- Personal (default active)
- Pact (disabled if not in pact, grayed out)
- Settings

---

## Personal Dashboard View

### Layout (Text Wireframe)

```
┌─────────────────────────────────────────────────────────────┐
│                     Personal Dashboard                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────┐  ┌───────────────────┐              │
│  │  Total Deaths     │  │  Highest Level    │              │
│  │       42          │  │       58          │              │
│  └───────────────────┘  └───────────────────┘              │
│                                                               │
│  ┌───────────────────┐  ┌───────────────────┐              │
│  │  Total Gold Lost  │  │  Total XP Lost    │              │
│  │   4,573g 28s 15c  │  │    12,485,992     │              │
│  └───────────────────┘  └───────────────────┘              │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Characters                                           │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ MyWarrior       Lvl 58  (12 deaths) [View Timeline] │   │
│  │ MyRogue         Lvl 42  (8 deaths)  [View Timeline] │   │
│  │ MyPaladin       Lvl 27  (5 deaths)  [View Timeline] │   │
│  │                                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  [View Timeline] [Export Data]                               │
└─────────────────────────────────────────────────────────────┘
```

### Stat Cards

Each stat card (Deaths, Highest Level, etc.) is a self-contained panel.

```lua
-- Stat card dimensions
local cardWidth = 280
local cardHeight = 70
local cardSpacing = 20

-- Card appearance
card:SetBackdropColor(0.15, 0.15, 0.15, 1)
card:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

-- Stat label (top)
local label = card:CreateFontString(nil, "OVERLAY")
label:SetFont(FONT_FAMILY, FONT_SIZE_SMALL, "OUTLINE")
label:SetText("Total Deaths")
label:SetPoint("TOP", card, "TOP", 0, -8)
label:SetTextColor(0.8, 0.8, 0.8, 1) -- Light gray

-- Stat value (center, large)
local value = card:CreateFontString(nil, "OVERLAY")
value:SetFont(FONT_FAMILY, 24, "OUTLINE") -- Larger font
value:SetText("42")
value:SetPoint("CENTER", card, "CENTER", 0, 0)
value:SetTextColor(1, 1, 1, 1) -- White

-- Color value based on context
-- Deaths: red gradient (more deaths = darker red)
-- Gold: gold color
-- Level: green (highest is good)
```

### Character List

Scrollable list of characters with death counts.

```lua
-- Character row appearance
local rowHeight = 30

-- Character name
local charName = row:CreateFontString(nil, "OVERLAY")
charName:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
charName:SetText("MyWarrior")
charName:SetPoint("LEFT", row, "LEFT", 8, 0)

-- Level text
local levelText = row:CreateFontString(nil, "OVERLAY")
levelText:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
levelText:SetText("Lvl 58")
levelText:SetPoint("LEFT", charName, "RIGHT", 10, 0)
levelText:SetTextColor(0, 1, 0, 1) -- Green for alive

-- Death count
local deathCount = row:CreateFontString(nil, "OVERLAY")
deathCount:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
deathCount:SetText("(12 deaths)")
deathCount:SetPoint("LEFT", levelText, "RIGHT", 10, 0)
deathCount:SetTextColor(0.8, 0.2, 0.2, 1) -- Red

-- View Timeline button
local viewButton = CreatePFUIButton(row, "View Timeline", 100, 22)
viewButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)
```

### Interaction Behaviors

**Stat Cards:**
- Hover: Lighten background slightly
- Tooltip: Show detailed breakdown (e.g., deaths per character)

**Character Rows:**
- Hover: Highlight row background
- Click character name: Switch to timeline view filtered to that character
- Click "View Timeline" button: Same as clicking name

**Action Buttons:**
- "View Timeline": Switch to Personal Timeline tab
- "Export Data": Execute `/bloodpact export personal` command

---

## Personal Timeline View

### Layout (Text Wireframe)

```
┌─────────────────────────────────────────────────────────────┐
│                     Personal Timeline                        │
├─────────────────────────────────────────────────────────────┤
│ Filter: [All Characters ▼] Sort: [Newest First ▼]           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Timeline (Scrollable)                                  │ │
│  │                                                         │ │
│  │ 2026-02-07 15:34:22  ●  DEATH                         │ │
│  │ MyWarrior (Lvl 58) killed by Wastewander Rogue (44)  │ │
│  │ Location: Tanaris (Gadgetzan)                         │ │
│  │ Lost: 245g 32s 18c, equipped: 3 rares                │ │
│  │ [View Details]                                         │ │
│  │                                                         │ │
│  │ 2026-02-05 09:12:45  ◆  MILESTONE                     │ │
│  │ MyWarrior reached level 50                            │ │
│  │                                                         │ │
│  │ 2026-02-01 21:03:11  ●  DEATH                         │ │
│  │ MyRogue (Lvl 42) killed by Fall Damage                │ │
│  │ Location: Thousand Needles                            │ │
│  │ Lost: 89g 14s 3c, equipped: 1 rare                   │ │
│  │ [View Details]                                         │ │
│  │                                                         │ │
│  │ ... (more events)                                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  [Back to Dashboard]                                         │
└─────────────────────────────────────────────────────────────┘
```

### Timeline Event Types

**Death Event (●)**
- Icon: Red circle
- Primary line: Character name, level, killer
- Secondary line: Location
- Tertiary line: Gold/items lost
- Expandable: "View Details" shows full equipment list

**Milestone Event (◆)**
- Icon: Gold diamond
- Primary line: Character name + milestone (e.g., "reached level 50")
- Milestones: Levels 10, 20, 30, 40, 50, 60

### Event Rendering

```lua
-- Death event appearance
local deathEvent = CreateFrame("Frame", nil, timeline)
deathEvent:SetHeight(80) -- Collapsed height
deathEvent:SetBackdropColor(0.2, 0.1, 0.1, 0.8) -- Dark red tint

-- Timestamp
local timestamp = deathEvent:CreateFontString(nil, "OVERLAY")
timestamp:SetFont(FONT_FAMILY, FONT_SIZE_SMALL, "OUTLINE")
timestamp:SetText("2026-02-07 15:34:22")
timestamp:SetPoint("TOPLEFT", deathEvent, "TOPLEFT", 8, -8)
timestamp:SetTextColor(0.7, 0.7, 0.7, 1) -- Gray

-- Death icon
local icon = deathEvent:CreateTexture(nil, "ARTWORK")
icon:SetWidth(16)
icon:SetHeight(16)
icon:SetTexture(1, 0, 0, 1) -- Red circle (or use texture)
icon:SetPoint("LEFT", timestamp, "RIGHT", 4, 0)

-- Label
local label = deathEvent:CreateFontString(nil, "OVERLAY")
label:SetFont(FONT_FAMILY, FONT_SIZE_SMALL, "OUTLINE")
label:SetText("DEATH")
label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
label:SetTextColor(1, 0.2, 0.2, 1) -- Bright red

-- Main text (character + killer)
local mainText = deathEvent:CreateFontString(nil, "OVERLAY")
mainText:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
mainText:SetText("MyWarrior (Lvl 58) killed by Wastewander Rogue (44)")
mainText:SetPoint("TOPLEFT", timestamp, "BOTTOMLEFT", 0, -4)
mainText:SetTextColor(1, 1, 1, 1)

-- Location text
local locationText = deathEvent:CreateFontString(nil, "OVERLAY")
locationText:SetFont(FONT_FAMILY, FONT_SIZE_SMALL, "OUTLINE")
locationText:SetText("Location: Tanaris (Gadgetzan)")
locationText:SetPoint("TOPLEFT", mainText, "BOTTOMLEFT", 0, -2)
locationText:SetTextColor(0.8, 0.8, 0.8, 1)

-- Lost items/gold summary
local lostText = deathEvent:CreateFontString(nil, "OVERLAY")
lostText:SetFont(FONT_FAMILY, FONT_SIZE_SMALL, "OUTLINE")
lostText:SetText("Lost: 245g 32s 18c, equipped: 3 rares")
lostText:SetPoint("TOPLEFT", locationText, "BOTTOMLEFT", 0, -2)
lostText:SetTextColor(1, 0.8, 0, 1) -- Gold color

-- View Details button (expands to show full item list)
local detailsButton = CreatePFUIButton(deathEvent, "View Details", 100, 20)
detailsButton:SetPoint("BOTTOMLEFT", deathEvent, "BOTTOMLEFT", 8, 8)
```

### Milestone Event Rendering

```lua
-- Milestone event appearance (simpler than death)
local milestoneEvent = CreateFrame("Frame", nil, timeline)
milestoneEvent:SetHeight(40)
milestoneEvent:SetBackdropColor(0.2, 0.2, 0.1, 0.6) -- Dark gold tint

-- Timestamp + icon + label (same as death)
-- Main text
local mainText = milestoneEvent:CreateFontString(nil, "OVERLAY")
mainText:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
mainText:SetText("MyWarrior reached level 50")
mainText:SetPoint("TOPLEFT", timestamp, "BOTTOMLEFT", 0, -4)
mainText:SetTextColor(1, 0.84, 0, 1) -- Gold
```

### Expanded Death Details

When "View Details" clicked, event expands to show full equipment list.

```
┌────────────────────────────────────────────────────────┐
│ 2026-02-07 15:34:22  ●  DEATH                         │
│ MyWarrior (Lvl 58) killed by Wastewander Rogue (44)   │
│ Location: Tanaris (51.3, 28.7)                        │
│ Lost: 245g 32s 18c                                    │
│                                                        │
│ Equipped Items:                                       │
│  • [Verigan's Fist] (Rare, MainHand)                 │
│  • [Helm of Valor] (Epic, Head)                      │
│  • [Ring of Protection] (Rare, Finger)               │
│                                                        │
│ [Hide Details]                                         │
└────────────────────────────────────────────────────────┘
```

### Filters and Sorting

**Filter Dropdown:**
- All Characters (default)
- Individual character names (one per character)

**Sort Dropdown:**
- Newest First (default)
- Oldest First
- Highest Level First

---

## Pact Dashboard View

### Layout (Text Wireframe)

```
┌─────────────────────────────────────────────────────────────┐
│                      Pact Dashboard                          │
├─────────────────────────────────────────────────────────────┤
│  Pact Name: The Fallen Legion                               │
│  Join Code: A7K9M2X5 [Copy]                                 │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────┐  ┌───────────────────┐              │
│  │  Total Deaths     │  │  Total Members    │              │
│  │       127         │  │     8 (6 alive)   │              │
│  └───────────────────┘  └───────────────────┘              │
│                                                               │
│  ┌───────────────────┐  ┌───────────────────┐              │
│  │  Highest Level    │  │  Total Gold Lost  │              │
│  │       60          │  │   18,492g 73s     │              │
│  └───────────────────┘  └───────────────────┘              │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Pact Members                                         │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ ✓ PlayerOne      Lvl 60  (18 deaths) ALIVE         │   │
│  │ ✓ PlayerTwo      Lvl 58  (22 deaths) ALIVE         │   │
│  │ ☠ PlayerThree    Lvl 42  (15 deaths) DECEASED       │   │
│  │ ✓ PlayerFour     Lvl 51  (31 deaths) ALIVE         │   │
│  │                                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  [View Pact Timeline] [Export Pact Data]                    │
└─────────────────────────────────────────────────────────────┘
```

### Pact Header

```lua
-- Pact name display
local pactNameLabel = frame:CreateFontString(nil, "OVERLAY")
pactNameLabel:SetFont(FONT_FAMILY, FONT_SIZE_LARGE, "OUTLINE")
pactNameLabel:SetText("Pact Name: The Fallen Legion")
pactNameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)

-- Join code display + copy button
local joinCodeLabel = frame:CreateFontString(nil, "OVERLAY")
joinCodeLabel:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
joinCodeLabel:SetText("Join Code: A7K9M2X5")
joinCodeLabel:SetPoint("TOPLEFT", pactNameLabel, "BOTTOMLEFT", 0, -4)

local copyButton = CreatePFUIButton(frame, "Copy", 50, 20)
copyButton:SetPoint("LEFT", joinCodeLabel, "RIGHT", 8, 0)
-- On click: Copy code to clipboard (if API available, else show message)
```

### Pact Member Roster

```lua
-- Member row appearance
local memberRow = CreateFrame("Frame", nil, memberList)
memberRow:SetHeight(30)

-- Alive/dead icon
local statusIcon = memberRow:CreateTexture(nil, "ARTWORK")
statusIcon:SetWidth(16)
statusIcon:SetHeight(16)
statusIcon:SetPoint("LEFT", memberRow, "LEFT", 8, 0)

-- Alive: green checkmark
if isAlive then
    statusIcon:SetTexture(0, 1, 0, 1) -- Green
else
    -- Dead: skull icon or red X
    statusIcon:SetTexture(1, 0, 0, 1) -- Red
end

-- Member name
local nameText = memberRow:CreateFontString(nil, "OVERLAY")
nameText:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
nameText:SetText("PlayerOne")
nameText:SetPoint("LEFT", statusIcon, "RIGHT", 4, 0)

-- Level
local levelText = memberRow:CreateFontString(nil, "OVERLAY")
levelText:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
levelText:SetText("Lvl 60")
levelText:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
if isAlive then
    levelText:SetTextColor(0, 1, 0, 1) -- Green
else
    levelText:SetTextColor(0.5, 0.5, 0.5, 1) -- Gray
end

-- Death count
local deathCountText = memberRow:CreateFontString(nil, "OVERLAY")
deathCountText:SetFont(FONT_FAMILY, FONT_SIZE_MEDIUM, "OUTLINE")
deathCountText:SetText("(18 deaths)")
deathCountText:SetPoint("LEFT", levelText, "RIGHT", 10, 0)
deathCountText:SetTextColor(0.8, 0.2, 0.2, 1)

-- Status label
local statusLabel = memberRow:CreateFontString(nil, "OVERLAY")
statusLabel:SetFont(FONT_FAMILY, FONT_SIZE_SMALL, "OUTLINE")
if isAlive then
    statusLabel:SetText("ALIVE")
    statusLabel:SetTextColor(0, 1, 0, 1)
else
    statusLabel:SetText("DECEASED")
    statusLabel:SetTextColor(1, 0, 0, 1)
end
statusLabel:SetPoint("RIGHT", memberRow, "RIGHT", -8, 0)
```

---

## Pact Timeline View

Very similar to Personal Timeline, but includes all pact members' deaths.

### Layout (Text Wireframe)

```
┌─────────────────────────────────────────────────────────────┐
│                       Pact Timeline                          │
├─────────────────────────────────────────────────────────────┤
│ Filter: [All Members ▼] Sort: [Newest First ▼]              │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Timeline (Scrollable)                                  │ │
│  │                                                         │ │
│  │ 2026-02-07 15:34:22  ●  DEATH                         │ │
│  │ PlayerOne's MyWarrior (Lvl 58)                        │ │
│  │ killed by Wastewander Rogue (44)                      │ │
│  │ Location: Tanaris (Gadgetzan)                         │ │
│  │ Lost: 245g 32s 18c                                    │ │
│  │ [View Details]                                         │ │
│  │                                                         │ │
│  │ 2026-02-06 12:08:33  ●  DEATH                         │ │
│  │ PlayerTwo's MageAlt (Lvl 42)                          │ │
│  │ killed by Pyrewood Sentry (43)                        │ │
│  │ Location: Silverpine Forest                           │ │
│  │ Lost: 78g 5s 22c                                      │ │
│  │ [View Details]                                         │ │
│  │                                                         │ │
│  │ ... (more events)                                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  [Back to Pact Dashboard]                                    │
└─────────────────────────────────────────────────────────────┘
```

### Differences from Personal Timeline

- **Member Attribution:** Each event shows which pact member's character died
  - Format: "PlayerOne's MyWarrior"
  - Color-coded by player (assign each member a unique color)
  
- **Filter Options:**
  - All Members (default)
  - Individual member names

### Player Color Coding

Assign each pact member a distinct color for visual differentiation.

```lua
local PLAYER_COLORS = {
    {1.0, 0.5, 0.5}, -- Light red
    {0.5, 0.5, 1.0}, -- Light blue
    {0.5, 1.0, 0.5}, -- Light green
    {1.0, 1.0, 0.5}, -- Light yellow
    {1.0, 0.5, 1.0}, -- Light magenta
    {0.5, 1.0, 1.0}, -- Light cyan
    {1.0, 0.8, 0.5}, -- Light orange
    {0.8, 0.5, 1.0}, -- Light purple
    -- Add more colors as needed
}

function GetPlayerColor(playerAccountID)
    -- Hash account ID to color index
    local hash = 0
    for i = 1, string.len(playerAccountID) do
        hash = hash + string.byte(playerAccountID, i)
    end
    
    local index = (hash % table.getn(PLAYER_COLORS)) + 1
    return PLAYER_COLORS[index]
end
```

---

## Pact Creation/Join Flow

### Pact Creation Flow

**Step 1: User Clicks "Create Pact" Button**
- Button location: Settings tab or Personal Dashboard
- Opens modal dialog

**Step 2: Creation Dialog**

```
┌─────────────────────────────────────────────┐
│           Create Blood Pact                 │
├─────────────────────────────────────────────┤
│                                             │
│  Pact Name:                                 │
│  ┌───────────────────────────────────────┐ │
│  │ The Fallen Legion                     │ │
│  └───────────────────────────────────────┘ │
│  (1-32 characters)                          │
│                                             │
│  [Cancel]                    [Create Pact] │
└─────────────────────────────────────────────┘
```

**Step 3: Pact Created - Show Join Code**

```
┌─────────────────────────────────────────────┐
│         Pact Created Successfully           │
├─────────────────────────────────────────────┤
│                                             │
│  Your Blood Pact has been created!          │
│                                             │
│  Join Code: A7K9M2X5                        │
│                                             │
│  Share this code with friends to invite     │
│  them to your pact.                         │
│                                             │
│  [Copy Code]                       [Close]  │
└─────────────────────────────────────────────┘
```

### Pact Join Flow

**Step 1: User Enters Join Code**
- Via UI: Settings tab has "Join Pact" section
- Via Command: `/bloodpact join A7K9M2X5`

**Step 2: Join Dialog (if using UI)**

```
┌─────────────────────────────────────────────┐
│             Join Blood Pact                 │
├─────────────────────────────────────────────┤
│                                             │
│  Join Code:                                 │
│  ┌───────────────────────────────────────┐ │
│  │ A7K9M2X5                              │ │
│  └───────────────────────────────────────┘ │
│  (8 characters, letters and numbers)        │
│                                             │
│  [Cancel]                       [Join Pact] │
└─────────────────────────────────────────────┘
```

**Step 3: Validation & Joining**
- Show loading message: "Connecting to pact..."
- If successful: "Successfully joined [Pact Name]!"
- If failed: "Invalid join code. Please check and try again."

**Step 4: Sync Confirmation**
- "Syncing pact data with members... (this may take a moment)"
- Once complete: "You are now part of [Pact Name]!"

---

## Settings Panel

### Layout (Text Wireframe)

```
┌─────────────────────────────────────────────────────────────┐
│                         Settings                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Account Information                                  │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ Account ID: MyFirstCharacter                        │   │
│  │ Created: 2026-01-15 10:23:45                        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Blood Pact Membership                                │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ ○ Not in a pact                                     │   │
│  │                                                       │   │
│  │ Join Code:                                           │   │
│  │ ┌──────────────────┐                                │   │
│  │ │                  │  [Join Pact]                   │   │
│  │ └──────────────────┘                                │   │
│  │                                                       │   │
│  │           - OR -                                     │   │
│  │                                                       │   │
│  │ [Create New Pact]                                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Data Management                                      │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ [Export Personal Data] [Export Pact Data]           │   │
│  │ [Wipe All Data]                                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ UI Preferences                                       │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ UI Scale: [75%] [100%] [125%] [150%]                │   │
│  │ □ Show timeline by default                           │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Settings Sections

**Account Information**
- Read-only display of account ID and creation date
- No user interaction needed

**Blood Pact Membership**
- If not in pact: Show join code input + "Join Pact" button + "Create New Pact" button
- If in pact: Show pact name, member count, "Leave Pact" button (future feature)

**Data Management**
- Export buttons execute respective commands
- Wipe button shows confirmation dialog (see below)

**UI Preferences**
- UI Scale: Radio buttons for different scale factors
- Checkboxes for various display preferences

### Wipe Confirmation Dialog

```
┌─────────────────────────────────────────────┐
│               WARNING                        │
├─────────────────────────────────────────────┤
│                                             │
│  Are you sure you want to wipe ALL death   │
│  data? This action cannot be undone.        │
│                                             │
│  Your account ID and pact membership will   │
│  be preserved.                              │
│                                             │
│  Type /bloodpact wipe confirm in chat to    │
│  proceed.                                   │
│                                             │
│  [Cancel]                                   │
└─────────────────────────────────────────────┘
```

---

## Slash Commands

### Command Summary

| Command | Description | Example |
|---------|-------------|---------|
| `/bloodpact` | Show main UI window | `/bloodpact` |
| `/bloodpact show` | Show main UI window | `/bloodpact show` |
| `/bloodpact hide` | Hide main UI window | `/bloodpact hide` |
| `/bloodpact toggle` | Toggle UI visibility | `/bloodpact toggle` |
| `/bloodpact join <code>` | Join a pact | `/bloodpact join A7K9M2X5` |
| `/bloodpact export personal` | Export personal data | `/bloodpact export personal` |
| `/bloodpact export pact` | Export pact data | `/bloodpact export pact` |
| `/bloodpact wipe` | Show wipe confirmation | `/bloodpact wipe` |
| `/bloodpact wipe confirm` | Execute data wipe | `/bloodpact wipe confirm` |
| `/bloodpact help` | Show command help | `/bloodpact help` |

### Help Text Output

```
Blood Pact v1.0 - Hardcore Death Tracker
Commands:
  /bloodpact or /bloodpact show - Open the Blood Pact window
  /bloodpact hide - Close the Blood Pact window
  /bloodpact toggle - Toggle window visibility
  /bloodpact join <code> - Join a Blood Pact using a join code
  /bloodpact export personal - Export your death data to JSON
  /bloodpact export pact - Export entire pact data to JSON
  /bloodpact wipe - Wipe all death data (requires confirmation)
  /bloodpact help - Show this help message

For more information, visit: github.com/username/blood-pact
```

---

## User Flows

### Flow 1: First-Time User - Viewing Personal Stats

1. User installs Blood Pact addon
2. Logs in with a hardcore character
3. Account ID automatically generated from character name
4. User types `/bloodpact` to open UI
5. Personal Dashboard shown by default
6. User sees "0 deaths" in stats (first character)
7. User explores UI, sees empty timeline
8. User clicks Settings tab, confirms account ID is set

**Expected Outcome:** User understands their account has been initialized and is ready to track deaths.

### Flow 2: First Death - Automatic Tracking

1. User's hardcore character dies in combat
2. Addon detects death via combat log parsing
3. Death data captured (location, killer, gear, gold)
4. Death saved to SavedVariables
5. Next time user opens UI, death appears in Personal Dashboard and Timeline
6. User clicks on death event to see full details

**Expected Outcome:** User sees comprehensive death record without any manual input.

### Flow 3: Creating a Blood Pact

1. User clicks "Create New Pact" in Settings tab
2. Creation dialog appears
3. User enters pact name: "The Fallen Legion"
4. User clicks "Create Pact"
5. Success dialog shows join code: "A7K9M2X5"
6. User copies join code and shares with friends (Discord, in-game whisper)
7. User closes dialog, Pact tab is now enabled
8. User switches to Pact Dashboard, sees 1 member (themselves)

**Expected Outcome:** Pact created successfully, ready for friends to join.

### Flow 4: Joining a Blood Pact

1. User receives join code from friend: "A7K9M2X5"
2. User types `/bloodpact join A7K9M2X5` in chat
3. Addon validates code format
4. Addon sends join request to pact members via addon channel
5. Pact owner's addon receives request, responds with pact data
6. User's addon receives response, syncs death histories
7. Success message: "Successfully joined The Fallen Legion!"
8. User opens UI, Pact tab now available
9. User switches to Pact Dashboard, sees all members
10. User switches to Pact Timeline, sees other members' deaths

**Expected Outcome:** User successfully joined pact and can view shared statistics.

### Flow 5: Viewing Pact Timeline After Member Death

1. User is in a pact with 3 friends
2. One friend's character dies (user is online)
3. Friend's addon broadcasts death to pact
4. User's addon receives death event within 10 seconds
5. User has Blood Pact UI open on Pact Timeline tab
6. Timeline automatically updates with new death event at top
7. User sees: "PlayerTwo's MageAlt (Lvl 42) killed by..."
8. User clicks "View Details" to see full death information

**Expected Outcome:** Real-time awareness of pact member deaths without manual refresh.

### Flow 6: Exporting Data

1. User wants to preserve death data externally
2. User opens Blood Pact UI, goes to Settings tab
3. User clicks "Export Personal Data" button
4. Addon generates JSON file with all death records
5. File saved to: `WTF/Account/<AccountName>/SavedVariables/BloodPact_Export_20260207_153422.json`
6. Success message with file path shown in chat
7. User navigates to file, opens in text editor or external tool
8. User sees structured JSON with all death metadata

**Expected Outcome:** User has permanent backup of death data in portable format.

### Flow 7: Data Wipe (Fresh Start)

1. User wants to reset all death statistics
2. User opens Settings tab, clicks "Wipe All Data"
3. Warning dialog appears explaining action is irreversible
4. Dialog instructs user to type `/bloodpact wipe confirm`
5. User types command in chat
6. Addon wipes all death records from SavedVariables
7. Account ID and pact membership preserved
8. UI updates to show 0 deaths
9. Confirmation message: "All death data has been wiped."

**Expected Outcome:** User's death history cleared, addon ready for fresh tracking.

---

## Accessibility

### Keyboard Navigation

- Tab key cycles through interactive elements
- Enter key activates buttons
- Escape key closes dialogs and main window

### Color Blindness Considerations

- Never rely solely on color to convey information
- Use icons (✓ for alive, ☠ for dead) in addition to color
- Provide text labels for all status indicators

### Font Size Options

- UI Scale setting affects all text proportionally
- Minimum font size: 10pt (readable on standard monitors)
- Maximum font size: 16pt (for accessibility needs)

### Screen Reader Compatibility

- All UI elements have descriptive names
- Hover tooltips provide additional context
- Status changes announced via chat messages

---

## Responsive Design

### Resolution Support

**Minimum Resolution:** 1024x768
- UI window fits within safe screen area
- All text remains readable
- Scrollbars appear for content overflow

**Common Resolutions:**
- 1280x720 (720p)
- 1920x1080 (1080p)
- 2560x1440 (1440p)

### Window Scaling

User can adjust UI scale in Settings:
- 75% (compact for large monitors)
- 100% (default)
- 125% (larger for readability)
- 150% (accessibility)

### Mobile Considerations

Blood Pact is for WoW 1.12 client only (desktop PC game). No mobile version required.

---

## Animation and Transitions

### Subtle Animations

**Window Open/Close:**
- Fade in: 0.2 seconds
- Fade out: 0.15 seconds

**Tab Switching:**
- Cross-fade: 0.15 seconds

**Hover Effects:**
- Background lighten: Instant
- Tooltip appear: 0.5 second delay

**Timeline Updates:**
- New event: Fade in over 0.3 seconds
- Highlight for 2 seconds (subtle pulse)

### Performance Considerations

- Animations disabled during combat (performance priority)
- Option to disable all animations in Settings

---

## Error States and Feedback

### Common Error Messages

**Invalid Join Code:**
```
[Blood Pact] Invalid join code format.
Join codes are 8 characters (letters and numbers).
Example: A7K9M2X5
```

**Already in Pact:**
```
[Blood Pact] You are already in a Blood Pact.
You must leave your current pact before joining another.
(Note: Leaving pacts not yet implemented in v1.0)
```

**Export Failed:**
```
[Blood Pact] ERROR: Could not write export file.
Check that your WTF folder is writable.
Path: WTF/Account/<AccountName>/SavedVariables/
```

**Corrupted Data:**
```
[Blood Pact] WARNING: Some death records were corrupted and removed.
Your addon will continue functioning with remaining data.
```

### Success Messages

**Death Recorded:**
```
[Blood Pact] Death recorded: <CharacterName> (Lvl <Level>)
```

**Pact Created:**
```
[Blood Pact] Pact created: <PactName>
Join Code: <JoinCode>
```

**Pact Joined:**
```
[Blood Pact] Successfully joined: <PactName>
Syncing data with members...
```

**Data Exported:**
```
[Blood Pact] Data exported successfully.
File: WTF/.../BloodPact_Export_<timestamp>.json
```

---

## Tooltip Guidelines

### When to Show Tooltips

- Stat cards: Hover for detailed breakdown
- Timeline events: Hover for additional context
- Buttons: Hover for action description
- Member names: Hover for full character list

### Tooltip Content Example

**Stat Card Tooltip (Total Deaths):**
```
Total Deaths: 42

Breakdown by Character:
• MyWarrior: 18 deaths
• MyRogue: 12 deaths
• MyPaladin: 7 deaths
• MyMage: 5 deaths
```

**Timeline Event Tooltip (Collapsed Death):**
```
Death Details:
Zone: Tanaris
Coordinates: 51.3, 28.7
Total XP Lost: 485,000

Equipped Items Lost:
• Verigan's Fist (Rare)
• Helm of Valor (Epic)
• Ring of Protection (Rare)

Click "View Details" for full information.
```

---

## Visual Design Mockup (ASCII)

### Main Window - Personal Dashboard

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Blood Pact                                    [_][■][X] ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ [Personal] [Pact] [Settings]                            ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                          ┃
┃   ╔═══════════════╗  ╔═══════════════╗                 ┃
┃   ║ Total Deaths  ║  ║ Highest Level ║                 ┃
┃   ║               ║  ║               ║                 ┃
┃   ║      42       ║  ║      58       ║                 ┃
┃   ║               ║  ║               ║                 ┃
┃   ╚═══════════════╝  ╚═══════════════╝                 ┃
┃                                                          ┃
┃   ╔═══════════════╗  ╔═══════════════╗                 ┃
┃   ║ Gold Lost     ║  ║ XP Lost       ║                 ┃
┃   ║               ║  ║               ║                 ┃
┃   ║ 4,573g 28s    ║  ║ 12,485,992    ║                 ┃
┃   ║               ║  ║               ║                 ┃
┃   ╚═══════════════╝  ╚═══════════════╝                 ┃
┃                                                          ┃
┃   ╔═══════════════════════════════════════════════════╗ ┃
┃   ║ Characters                                        ║ ┃
┃   ╟───────────────────────────────────────────────────╢ ┃
┃   ║ MyWarrior    Lvl 58  (18 deaths)  [View Timeline]║ ┃
┃   ║ MyRogue      Lvl 42  (12 deaths)  [View Timeline]║ ┃
┃   ║ MyPaladin    Lvl 27  (7 deaths)   [View Timeline]║ ┃
┃   ║ MyMage       Lvl 19  (5 deaths)   [View Timeline]║ ┃
┃   ║                                                   ║ ┃
┃   ╚═══════════════════════════════════════════════════╝ ┃
┃                                                          ┃
┃   [View Timeline]  [Export Data]                        ┃
┃                                                          ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ Account ID: MyFirstCharacter    │    Blood Pact v1.0   ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

---

## Implementation Priority

### Phase 1 (MVP)
1. Main window frame and tab structure
2. Personal Dashboard with stat cards
3. Character list display
4. Settings panel (account info only)

### Phase 2
5. Personal Timeline with death event rendering
6. Milestone markers on timeline
7. Expandable death details

### Phase 3
8. Pact creation dialog and join code generation
9. Pact join dialog and validation
10. Pact Dashboard with member roster
11. Pact Timeline with multi-member display

### Phase 4
12. Data export functionality
13. Data wipe with confirmation
14. Polish: animations, tooltips, hover effects
15. UI scaling options

---

## Testing Checklist

### Visual Testing
- [ ] All text readable at 1024x768 minimum resolution
- [ ] Colors match PFUI aesthetic
- [ ] Proper alignment at all UI scale settings
- [ ] No text overflow or clipping
- [ ] Tooltips appear correctly positioned
- [ ] Scrollbars function smoothly

### Interaction Testing
- [ ] All buttons respond to clicks
- [ ] Tab switching works correctly
- [ ] Dialogs open and close properly
- [ ] Slash commands trigger UI actions
- [ ] Keyboard navigation functional
- [ ] Window draggable by title bar

### Data Display Testing
- [ ] Death counts accurate
- [ ] Timeline events in correct order
- [ ] Item quality colors correct
- [ ] Gold formatting correct (g/s/c)
- [ ] Timestamps display server time
- [ ] Character level colors appropriate

### Pact UI Testing
- [ ] Join code displays correctly
- [ ] Member roster updates on join
- [ ] Pact timeline shows all members
- [ ] Player color coding distinct
- [ ] Alive/dead status accurate

---

## Future UI Enhancements (Post-1.0)

- Graphical timeline with visual markers (not just text list)
- Mini-map button for quick access
- Death location map integration
- Character portraits in member roster
- Animated death notifications (toast popups)
- Achievements/milestones UI
- Comparison view (your stats vs pact average)
- Dark mode / Light mode toggle
- Custom PFUI theme support

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-07 | Justin | Initial UI/UX specification |

---

**End of UI/UX Specification Document**
