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
    else
        SetNightvision(true)
    end

    -- Apply HUD color replacements
    ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED, Config.RGBA.LINE.GREEN, Config.RGBA.LINE.BLUE, Config.RGBA.LINE.ALPHA)
    ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED, Config.RGBA.STYLE.GREEN, Config.RGBA.STYLE.BLUE, Config.RGBA.STYLE.ALPHA)
    ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)
    
    while opacity <= 1.0 do
        SetTimecycleModifierStrength(opacity)
        opacity = opacity + step
        Wait(1)
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

-- Function to get character information including the phone number and job title
function GetCharacterInfo()
    local name, serverId, bankBalance, cashBalance, phoneNumber, jobTitle
    if Config.Framework == "QBCore" then
        local playerData = exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
        name = playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname
        bankBalance = playerData.money["bank"]
        cashBalance = playerData.money["cash"]
        phoneNumber = playerData.charinfo.phone
        jobTitle = playerData.job.name
    elseif Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerData()
        name = xPlayer.getName()  -- Adapt based on your ESX version's method of fetching name
        bankBalance = xPlayer.getAccount('bank').money
        cashBalance = xPlayer.getMoney()
        phoneNumber = xPlayer.get('phone')  -- Verify this key based on your data structure
        jobTitle = xPlayer.job.label
    end
    serverId = GetPlayerServerId(PlayerId())
    return name, serverId, bankBalance, cashBalance, phoneNumber, jobTitle
end

-- Main script thread
CreateThread(function()
    ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED, Config.RGBA.LINE.GREEN, Config.RGBA.LINE.BLUE, Config.RGBA.LINE.ALPHA)
    ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED, Config.RGBA.STYLE.GREEN, Config.RGBA.STYLE.BLUE, Config.RGBA.STYLE.ALPHA)
    ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)
    
    ApplyTextReplacements()

    while true do
        Wait(1)
        if IsPauseMenuActive() then
            if not filterEnabled then
                ApplyFilter(10)  -- Duration for the filter effect
                filterEnabled = true
            end
            if Config.Framework ~= "ESX" then  -- Only display info if not using ESX
                local characterName, characterId, bankBalance, cashBalance, phoneNumber, jobTitle = GetCharacterInfo()
                local characterBalance = "Bank: $" .. bankBalance .. " | Cash: $" .. cashBalance
                local idAndPhoneNumber = "ID: " .. characterId .. " | Phone: " .. phoneNumber
                local topRowText = characterName .. " - " .. jobTitle
                
                SetScriptGfxDrawBehindPausemenu(true)
                BeginScaleformMovieMethodOnFrontendHeader("SET_HEADING_DETAILS")
                PushScaleformMovieFunctionParameterString(topRowText)
                PushScaleformMovieFunctionParameterString(characterBalance)
                PushScaleformMovieFunctionParameterString(idAndPhoneNumber)
                EndScaleformMovieMethod()
            end
        elseif filterEnabled then
            RemoveFilter()
            filterEnabled = false
        end
    end
end)
