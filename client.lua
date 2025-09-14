--========================
-- cr-pause | client.lua
--========================

-- Text replacement (pause title)
function ApplyTextReplacements()
    local replacer = {
        ["TITLE"] = "FE_THDR_GTAO",  -- Key for the main pause menu title
    }
    for key, entry in pairs(replacer) do
        if Config.Header and Config.Header[key] then
            AddTextEntry(entry, Config.Header[key])
        end
    end
end

-- Native wrapper (add text entry)
function AddTextEntry(key, value)
    Citizen.InvokeNative(0x32CA01C3, key, value)
end

-- -------------------------
-- Night-vision filter setup
-- -------------------------
local filterEnabled = false

-- Defaults if missing in config
local FILTER_NAME     = (Config and Config.CustomTimeCycleModifier) or 'cr-pause'
local FILTER_STRENGTH = (Config and Config.FilterStrength) or 1.0      -- 0.0–1.0
local FADE_MS         = (Config and Config.FadeMs) or 650
local USE_CUSTOM      = (Config and Config.UseCustomFilter) ~= false    -- default true
local STACK_VANILLA   = (Config and Config.StackVanillaNV) or false     -- optional: stack vanilla NV brightness

local function FadeWait(ms)
    local t = GetGameTimer() + (ms or 0)
    while GetGameTimer() < t do Wait(0) end
end

-- Apply the visual filter when the pause menu opens
function ApplyFilter()
    -- HUD color replacements
    if Config and Config.RGBA then
        ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED,     Config.RGBA.LINE.GREEN,     Config.RGBA.LINE.BLUE,     Config.RGBA.LINE.ALPHA)
        ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED,    Config.RGBA.STYLE.GREEN,    Config.RGBA.STYLE.BLUE,    Config.RGBA.STYLE.ALPHA)
        ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)
    end

    if USE_CUSTOM then
        if STACK_VANILLA then SetNightvision(true) end
        -- Smoothly fade in your streamed timecycle
        SetTransitionTimecycleModifier(FILTER_NAME, FILTER_STRENGTH)
        FadeWait(FADE_MS)
    else
        -- Vanilla NV look (no custom modifier)
        SetNightvision(true)
    end

    if Config and Config.DisplayLogo then
        SendNUIMessage({ display = true })
    end
end

-- Remove the filter when the pause menu closes
function RemoveFilter()
    if USE_CUSTOM then
        -- Fade out, then clear to restore world
        SetTimecycleModifierStrength(0.0)
        FadeWait(FADE_MS)
        ClearTimecycleModifier()
        if STACK_VANILLA then SetNightvision(false) end
    else
        SetNightvision(false)
    end

    if Config and Config.DisplayLogo then
        SendNUIMessage({ display = false })
    end
end

-- Character info (QBCore / ESX)
function GetCharacterInfo()
    local name, serverId, bankBalance, cashBalance, phoneNumber, jobTitle
    if Config and Config.Framework == "QBCore" then
        local QBCore = exports['qb-core']:GetCoreObject()
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData and playerData.charinfo then
            name = (playerData.charinfo.firstname or "") .. " " .. (playerData.charinfo.lastname or "")
            phoneNumber = playerData.charinfo.phone
        end
        if playerData and playerData.money then
            bankBalance = playerData.money["bank"] or 0
            cashBalance = playerData.money["cash"] or 0
        end
        jobTitle = (playerData.job and playerData.job.name) or "Unemployed"
    elseif Config and Config.Framework == "ESX" then
        if ESX == nil then ESX = exports['es_extended']:getSharedObject() end
        local xPlayer = ESX.GetPlayerData()
        name = (xPlayer.getName and xPlayer.getName()) or "Citizen"
        local bank = xPlayer.getAccount and xPlayer.getAccount('bank')
        bankBalance = bank and bank.money or 0
        cashBalance = (xPlayer.getMoney and xPlayer.getMoney()) or 0
        phoneNumber = (xPlayer.get and xPlayer.get('phone')) or "N/A"
        jobTitle = (xPlayer.job and xPlayer.job.label) or "Unemployed"
    else
        name, bankBalance, cashBalance, phoneNumber, jobTitle = "Citizen", 0, 0, "N/A", "Unemployed"
    end
    serverId = GetPlayerServerId(PlayerId())
    return name, serverId, bankBalance, cashBalance, phoneNumber, jobTitle
end

-- -------------------------
-- Main loop
-- -------------------------
CreateThread(function()
    -- Apply HUD colors once at start (also done inside ApplyFilter for safety)
    if Config and Config.RGBA then
        ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED,     Config.RGBA.LINE.GREEN,     Config.RGBA.LINE.BLUE,     Config.RGBA.LINE.ALPHA)
        ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED,    Config.RGBA.STYLE.GREEN,    Config.RGBA.STYLE.BLUE,    Config.RGBA.STYLE.ALPHA)
        ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)
    end

    ApplyTextReplacements()

    while true do
        Wait(1)
        if IsPauseMenuActive() then
            if not filterEnabled then
                ApplyFilter()
                filterEnabled = true
            end

            -- Top-row details (skip if ESX per your original logic)
            if not (Config and Config.Framework == "ESX") then
                local characterName, characterId, bankBalance, cashBalance, phoneNumber, jobTitle = GetCharacterInfo()
                local characterBalance = ("Bank: $%s | Cash: $%s"):format(bankBalance or 0, cashBalance or 0)
                local idAndPhoneNumber = ("ID: %s | Phone: %s"):format(characterId or "N/A", phoneNumber or "N/A")
                local topRowText = ("%s - %s"):format(characterName or "Citizen", jobTitle or "Unemployed")

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

-- Clean up on resource stop/restart
AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearTimecycleModifier()
    SetNightvision(false)
    if Config and Config.DisplayLogo then
        SendNUIMessage({ display = false })
    end
end)
