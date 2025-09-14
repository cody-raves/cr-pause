--========================
-- cr-pause | config.lua
--========================

Config = {}

-- Framework: "QBCore" or "ESX"
Config.Framework = "QBCore"

-- Pause header text
Config.Header = {
    TITLE = "cr-pause"
}

-- Show logo in your pause NUI
Config.DisplayLogo = true

-- HUD colors (NoPixel-style green accents)
Config.RGBA = {
    LINE    = { RED = 0,   GREEN = 249, BLUE = 185, ALPHA = 255 }, -- line above each option
    STYLE   = { RED = 0,   GREEN = 0,   BLUE = 0,   ALPHA = 180 }, -- option background
    WAYPOINT= { RED = 0,   GREEN = 249, BLUE = 185, ALPHA = 255 }  -- waypoint color
}

-- Night-vision / timecycle filter
Config.UseCustomFilter         = true                  -- use our streamed modifier
Config.CustomTimeCycleModifier = "cr-pause"            -- MUST match the <modifier name="cr-pause"> in your XML
Config.FilterStrength          = 1.0                   -- 0.0–1.0
Config.FadeMs                  = 650                   -- fade duration (ms)

-- Optional: stack vanilla NV brightness curve under your color grade
-- (If you prefer only your timecycle look, leave this false)
Config.StackVanillaNV          = false

-- Optional keybind/command support (only used if you add a manual toggle elsewhere)
Config.RegisterKeybind         = false                 -- you can set to true if you add a manual NV toggle
Config.NVCommand               = "nv"
Config.NVKey                   = "F10"

-- Note:
-- ESX vs QBCore may look slightly different depending on other visual packs running,
-- but this config forces your custom 'cr-pause' timecycle during pause, regardless.
