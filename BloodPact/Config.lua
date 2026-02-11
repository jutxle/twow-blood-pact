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
BLOODPACT_MANUAL_SYNC_FEEDBACK_DELAY = 12 -- Seconds to wait before showing manual sync feedback

-- UI
BLOODPACT_WINDOW_WIDTH    = 600
BLOODPACT_WINDOW_HEIGHT   = 450
BLOODPACT_WINDOW_MIN_W    = 500
BLOODPACT_WINDOW_MIN_H    = 400

-- Cumulative XP required to reach each level (Turtle WoW / vanilla 1.12)
-- Index = level, value = total XP earned when you ding to that level
-- Level 1 = 0 (starting), Level 2 = 400, ... Level 60 = 4,084,700
-- Source: https://turtle-wow.fandom.com/wiki/Experience_Chart
BLOODPACT_XP_PER_LEVEL = {
    [1]  = 0,
    [2]  = 400,
    [3]  = 1300,
    [4]  = 2700,
    [5]  = 4800,
    [6]  = 7600,
    [7]  = 11200,
    [8]  = 15700,
    [9]  = 21100,
    [10] = 27600,
    [11] = 35200,
    [12] = 44000,
    [13] = 54100,
    [14] = 65500,
    [15] = 78400,
    [16] = 92800,
    [17] = 108800,
    [18] = 126500,
    [19] = 145900,
    [20] = 167200,
    [21] = 190400,
    [22] = 215600,
    [23] = 242900,
    [24] = 272300,
    [25] = 304000,
    [26] = 338000,
    [27] = 374400,
    [28] = 413300,
    [29] = 454700,
    [30] = 499000,
    [31] = 546400,
    [32] = 597200,
    [33] = 651900,
    [34] = 710500,
    [35] = 773300,
    [36] = 840300,
    [37] = 911900,
    [38] = 988000,
    [39] = 1068800,
    [40] = 1154500,
    [41] = 1245200,
    [42] = 1341000,
    [43] = 1442000,
    [44] = 1548300,
    [45] = 1660100,
    [46] = 1777500,
    [47] = 1900700,
    [48] = 2029800,
    [49] = 2164900,
    [50] = 2306100,
    [51] = 2453600,
    [52] = 2607500,
    [53] = 2767900,
    [54] = 2935000,
    [55] = 3108900,
    [56] = 3289700,
    [57] = 3477600,
    [58] = 3672600,
    [59] = 3874900,
    [60] = 4084700
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

-- WoW class colors (English class name -> RGB)
BLOODPACT_CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43},
    PALADIN = {0.96, 0.55, 0.73},
    HUNTER  = {0.67, 0.83, 0.45},
    ROGUE   = {1.0, 0.96, 0.41},
    PRIEST  = {1.0, 1.0, 1.0},
    SHAMAN  = {0.0, 0.44, 0.87},
    MAGE    = {0.41, 0.8, 0.94},
    WARLOCK = {0.58, 0.51, 0.79},
    DRUID   = {1.0, 0.49, 0.04},
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
