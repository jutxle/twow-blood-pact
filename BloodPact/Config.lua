-- Blood Pact - Configuration Constants

BLOODPACT_VERSION        = "1.0.0"
BLOODPACT_SCHEMA_VERSION = 1

-- Death tracking
BLOODPACT_MAX_DEATHS_PER_CHAR = 25

-- Addon communication
BLOODPACT_ADDON_PREFIX       = "BLDPCT"  -- Must be <= 16 chars; keeping short for 1.12 safety
BLOODPACT_MSG_CHUNK_SIZE     = 200       -- Bytes per chunk (safe under 255 limit)
BLOODPACT_RATE_LIMIT_INTERVAL = 0.5      -- Minimum seconds between message sends
BLOODPACT_MSG_DEDUP_WINDOW   = 30        -- Seconds to cache received message IDs

-- Death detection timing
BLOODPACT_DEATH_CONFIRM_WINDOW = 3       -- Seconds to wait for PLAYER_DEAD after combat log signal
BLOODPACT_SUSPECT_TIMER_INTERVAL = 0.1   -- OnUpdate tick for death detection timer

-- Pact sync
BLOODPACT_JOIN_TIMEOUT    = 30           -- Seconds to wait for join response
BLOODPACT_CHUNK_TIMEOUT   = 30           -- Seconds before incomplete chunk buffers expire
BLOODPACT_SYNC_REQUEST_DELAY = 5         -- Seconds after login to send sync request

-- UI
BLOODPACT_WINDOW_WIDTH    = 600
BLOODPACT_WINDOW_HEIGHT   = 450
BLOODPACT_WINDOW_MIN_W    = 500
BLOODPACT_WINDOW_MIN_H    = 400

-- XP required to reach each level (vanilla WoW classic, cumulative from level 1)
-- Index = level, value = total XP needed to have reached that level
BLOODPACT_XP_PER_LEVEL = {
    [1]  = 0,
    [2]  = 400,
    [3]  = 900,
    [4]  = 1400,
    [5]  = 2100,
    [6]  = 2800,
    [7]  = 3600,
    [8]  = 4500,
    [9]  = 5400,
    [10] = 6500,
    [11] = 8000,
    [12] = 9500,
    [13] = 11000,
    [14] = 12500,
    [15] = 14000,
    [16] = 15500,
    [17] = 17000,
    [18] = 18500,
    [19] = 20000,
    [20] = 21500,
    [21] = 23000,
    [22] = 24500,
    [23] = 26000,
    [24] = 27500,
    [25] = 29000,
    [26] = 30500,
    [27] = 32000,
    [28] = 33500,
    [29] = 35000,
    [30] = 36500,
    [31] = 38000,
    [32] = 39500,
    [33] = 41000,
    [34] = 42500,
    [35] = 44000,
    [36] = 45500,
    [37] = 47000,
    [38] = 48500,
    [39] = 50000,
    [40] = 51500,
    [41] = 53000,
    [42] = 54500,
    [43] = 56000,
    [44] = 57500,
    [45] = 59000,
    [46] = 60500,
    [47] = 62000,
    [48] = 63500,
    [49] = 65000,
    [50] = 66500,
    [51] = 68000,
    [52] = 69500,
    [53] = 71000,
    [54] = 72500,
    [55] = 74000,
    [56] = 75500,
    [57] = 77000,
    [58] = 78500,
    [59] = 80000,
    [60] = 81500
}

-- Colors (used across UI modules)
BLOODPACT_COLORS = {
    -- UI structure
    TEXT_PRIMARY   = {1.0, 1.0, 1.0},
    TEXT_SECONDARY = {0.8, 0.8, 0.8},
    TEXT_DISABLED  = {0.4, 0.4, 0.4},
    TEXT_ERROR     = {1.0, 0.27, 0.27},
    TEXT_SUCCESS   = {0.27, 1.0, 0.27},

    -- Status
    ALIVE          = {0.0, 1.0, 0.0},
    DECEASED       = {0.6, 0.0, 0.0},

    -- Events
    DEATH_RED      = {0.55, 0.0, 0.0},
    MILESTONE_GOLD = {1.0, 0.84, 0.0},

    -- Pact
    PACT_BLUE      = {0.25, 0.41, 0.88},

    -- Item quality (WoW standard)
    QUALITY_COMMON    = {1.0, 1.0, 1.0},
    QUALITY_UNCOMMON  = {0.12, 1.0, 0.0},
    QUALITY_RARE      = {0.0, 0.44, 0.87},
    QUALITY_EPIC      = {0.64, 0.21, 0.93},
    QUALITY_LEGENDARY = {1.0, 0.5, 0.0},
}

-- Per-player timeline color cycling
BLOODPACT_PLAYER_COLORS = {
    {1.0, 0.5, 0.5},
    {0.5, 0.5, 1.0},
    {0.5, 1.0, 0.5},
    {1.0, 1.0, 0.5},
    {1.0, 0.5, 1.0},
    {0.5, 1.0, 1.0},
    {1.0, 0.8, 0.5},
    {0.8, 0.5, 1.0},
}
