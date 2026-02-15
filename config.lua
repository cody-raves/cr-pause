-- Configuration settings
Config = {}

Config.Framework = "QBCore"  -- Options: "QBCore", "ESX"

Config.Header = {
    TITLE = "cr-pause"  -- Customize the main title
}

-- Configuration for logo display
Config.DisplayLogo = true  -- Set to false to disable the logo, true to enable it

-- Configuration for colors
Config.RGBA = {
    LINE = {RED = 0, GREEN = 249, BLUE = 185, ALPHA = 255},  -- Line color above each option (default nopixel-green)
    STYLE = {RED = 0, GREEN = 0, BLUE = 0, ALPHA = 180},  -- Background color of each option (default black semi-transparent)
    WAYPOINT = {RED = 0, GREEN = 249, BLUE = 185, ALPHA = 255}  -- Waypoint color on the map (default nopixel-green)
}

-- Configuration for using a custom time cycle modifier

-- Background / screen treatment while pause menu is open
-- Mode options:
--   "filter" = apply timecycle/nightvision filter (uses Config.UseCustomFilter + Config.CustomTimeCycleModifier below)
--   "none"   = no filter and no color overlay
--   "color"  = draw a fullscreen color overlay behind the pause menu (uses Config.BackgroundColor)
Config.BackgroundMode = "color"

-- Used only when Config.BackgroundMode = "color"
-- Tip: keep ALPHA between ~80-200 for a subtle tint
Config.BackgroundColor = {RED = 50, GREEN = 130, BLUE = 246, ALPHA = 160}

-- Fade speed (higher = slower). 10 matches the old behavior.
Config.BackgroundFadeSteps = 10

Config.UseCustomFilter = false -- Set to true to use a custom filter, false to use default nightvision
Config.CustomTimeCycleModifier = "damage" -- list of modifiers here https://wiki.rage.mp/index.php?title=Timecycle_Modifiers

--info: filters on ESX look diffrent than the ones QBCORE uses. for example 'nightvision' is more bright green in ESX and its more dark green in QBCORE
