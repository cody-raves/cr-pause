--========================
-- cr-pause | config.lua
--========================

Config = {}

-- Framework: "QBCore" or "ESX"
Config.Framework = "QBCore"

-- Pause header text
Config.Header = {
    TITLE = "cr-pause"  -- Customize the main title
}

-- Logo toggle
Config.DisplayLogo = true

-- HUD colors (NoPixel-style)
Config.RGBA = {
    LINE    = { RED = 0,   GREEN = 249, BLUE = 185, ALPHA = 255 },
    STYLE   = { RED = 0,   GREEN = 0,   BLUE = 0,   ALPHA = 180 },
    WAYPOINT= { RED = 0,   GREEN = 249, BLUE = 185, ALPHA = 255 }
}

-- NV / Timecycle
Config.UseCustomFilter         = false
Config.CustomTimeCycleModifier = "damage" -- defaults to GTA’s built-ins unless you swap
