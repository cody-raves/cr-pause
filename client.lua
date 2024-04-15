-- Configuration for text replacement in the pause menu
function ApplyTextReplacements()
    local replacer = {
        ["TITLE"] = "FE_THDR_GTAO",  -- Key for the main pause menu title
    }

    -- Loop through the replacer to apply text entries
    for key, entry in pairs(replacer) do
        if Config.Header[key] then
            AddTextEntry(entry, Config.Header[key])
        end
    end
end

-- Native function wrapper to add text entries
function AddTextEntry(key, value)
    Citizen.InvokeNative(0x32CA01C3, key, value)
end

local nightvisionEnabled = false

-- Function to fade nightvision in
function fadeNightvisionIn(duration)
    local step = 1.0 / duration
    local opacity = 0.0
    while opacity <= 1.0 do
        SetNightvision(true)
        SetTimecycleModifierStrength(opacity)
        opacity = opacity + step
        Wait(100)  -- Wait 100 milliseconds before the next increment
    end
end

-- Main script thread
CreateThread(function()
    -- Apply pause menu color customizations once at the start
    ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED, Config.RGBA.LINE.GREEN, Config.RGBA.LINE.BLUE, Config.RGBA.LINE.ALPHA)
    ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED, Config.RGBA.STYLE.GREEN, Config.RGBA.STYLE.BLUE, Config.RGBA.STYLE.ALPHA)
    ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)

    ApplyTextReplacements()  -- Apply text changes

    while true do
        Wait(1)  -- Efficient checking in sync with game frames
        if IsPauseMenuActive() and not nightvisionEnabled then
            fadeNightvisionIn(10)  -- Fade in over approximately 1 second
            nightvisionEnabled = true
        elseif not IsPauseMenuActive() and nightvisionEnabled then
            SetNightvision(false)  -- Turn off nightvision immediately when pause menu is inactive
            nightvisionEnabled = false
        end
    end
end)

