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

local filterEnabled = false

-- Function to apply the appropriate filter based on configuration
function ApplyFilter(duration)
    local step = 1.0 / duration
    local opacity = 0.0
    if Config.UseCustomFilter then
        SetTimecycleModifier(Config.CustomTimeCycleModifier)
        while opacity <= 1.0 do
            SetTimecycleModifierStrength(opacity)
            opacity = opacity + step
            Wait(1)
        end
    else
        SetNightvision(true)
        while opacity <= 1.0 do
            SetTimecycleModifierStrength(opacity)
            opacity = opacity + step
            Wait(1)
        end
    end
    if Config.DisplayLogo then
        SendNUIMessage({ display = true })
    end
end

-- Function to remove the filter
function RemoveFilter()
    if Config.UseCustomFilter then
        ClearTimecycleModifier()
    else
        SetNightvision(false)
    end
    if Config.DisplayLogo then
        SendNUIMessage({ display = false })
    end
end

-- Main script thread
CreateThread(function()
    -- Apply pause menu color customizations once at the start
    ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED, Config.RGBA.LINE.GREEN, Config.RGBA.LINE.BLUE, Config.RGBA.LINE.ALPHA)
    ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED, Config.RGBA.STYLE.GREEN, Config.RGBA.STYLE.BLUE, Config.RGBA.STYLE.ALPHA)
    ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)

    ApplyTextReplacements()

    while true do
        Wait(1)
        if IsPauseMenuActive() and not filterEnabled then
            ApplyFilter(10)  -- Apply filter over approximately 1 second
            filterEnabled = true
        elseif not IsPauseMenuActive() and filterEnabled then
            RemoveFilter()  -- Remove filter when pause menu is deactivated
            filterEnabled = false
        end
    end
end)
