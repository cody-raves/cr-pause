--========================
-- cr-pause | client.lua
--========================

-- === Pause title ===
local function ApplyTextReplacements()
    local replacer = { ["TITLE"] = "FE_THDR_GTAO" }
    for key, entry in pairs(replacer) do
        if Config.Header[key] then
            Citizen.InvokeNative(0x32CA01C3, entry, Config.Header[key])
        end
    end
end

-- === State ===
local filterEnabled = false
local ESX, QBCore
local cached = {
    name = nil, bank = 0, cash = 0, phone = "N/A", job = "Unemployed",
}

-- === Helpers ===
local function EnsureESX()
    if ESX then return ESX end
    if exports and exports['es_extended'] and exports['es_extended'].getSharedObject then
        ESX = exports['es_extended']:getSharedObject()
    else
        ESX = exports["es_extended"]:getSharedObject()
    end
    return ESX
end

local function EnsureQBCore()
    if QBCore then return QBCore end
    if exports['qb-core'] and exports['qb-core'].GetCoreObject then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    return QBCore
end

local function LoadFrameworkDataBlocking()
    if Config.Framework == "ESX" then
        EnsureESX()
        -- wait until ESX data is populated
        local pd = ESX.GetPlayerData()
        local tries = 0
        while (not pd or not pd.job) and tries < 200 do
            Wait(50)
            pd = ESX.GetPlayerData()
            tries = tries + 1
        end
    elseif Config.Framework == "QBCore" then
        EnsureQBCore()
        local pd = QBCore and QBCore.Functions.GetPlayerData()
        local tries = 0
        while (not pd or not pd.job) and tries < 200 do
            Wait(50)
            pd = QBCore.Functions.GetPlayerData()
            tries = tries + 1
        end
    end
end

-- === Data refreshers ===
local function RefreshFromESX()
    local x = ESX and ESX.GetPlayerData()
    if not x then return end

    -- Name
    if x.firstName and x.lastName then
        cached.name = (x.firstName .. " " .. x.lastName)
    elseif x.name then
        cached.name = x.name
    else
        cached.name = GetPlayerName(PlayerId())
    end

    -- Money
    local bank, cash = 0, 0
    if type(x.accounts) == "table" then
        for _, acc in ipairs(x.accounts) do
            if acc.name == 'bank' then bank = acc.money or acc.balance or 0 end
            if acc.name == 'money' or acc.name == 'cash' then
                cash = acc.money or acc.balance or cash
            end
        end
    elseif type(x.money) == "number" then
        cash = x.money
    end
    cached.bank, cached.cash = bank, cash

    -- Phone (handles multiple phones/forks)
    cached.phone =
        (x.get and (x.get('phone_number') or x.get('phone'))) or
        (x.metadata and (x.metadata.phone_number or x.metadata.phone)) or
        (x.variables and x.variables.phone_number) or
        "N/A"

    -- Job
    cached.job = (x.job and (x.job.label or x.job.name)) or "Unemployed"
end

local function RefreshFromQB()
    local Q = EnsureQBCore()
    if not Q then return end
    local p = Q.Functions.GetPlayerData()
    if not p then return end

    cached.name = (p.charinfo and (p.charinfo.firstname .. " " .. p.charinfo.lastname)) or GetPlayerName(PlayerId())
    cached.bank = (p.money and p.money["bank"]) or 0
    cached.cash = (p.money and p.money["cash"]) or 0
    cached.phone = (p.charinfo and p.charinfo.phone) or "N/A"
    cached.job = (p.job and (p.job.label or p.job.name)) or "Unemployed"
end

local function RefreshCached()
    if Config.Framework == "ESX" then
        EnsureESX()
        RefreshFromESX()
    else
        EnsureQBCore()
        RefreshFromQB()
    end
end

-- === Filter ===
local function ApplyFilter(duration)
    local step = 1.0 / duration
    local opacity = 0.0

    if Config.UseCustomFilter then
        SetTimecycleModifier(Config.CustomTimeCycleModifier)
    else
        SetNightvision(true)
    end

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

local function RemoveFilter()
    if Config.UseCustomFilter then
        ClearTimecycleModifier()
    else
        SetNightvision(false)
    end
    if Config.DisplayLogo then
        SendNUIMessage({ display = false })
    end
end

-- === ESX/QBCore event hooks to keep data fresh ===
if Config.Framework == "ESX" then
    CreateThread(function()
        EnsureESX()
        LoadFrameworkDataBlocking()
        RefreshFromESX()
    end)

    RegisterNetEvent('esx:playerLoaded', function()
        RefreshFromESX()
    end)
    RegisterNetEvent('esx:setJob', function()
        RefreshFromESX()
    end)
    -- Some phones set metadata later:
    RegisterNetEvent('esx:registerSuggestions', function()
        RefreshFromESX()
    end)
else
    CreateThread(function()
        EnsureQBCore()
        LoadFrameworkDataBlocking()
        RefreshFromQB()
    end)

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        RefreshFromQB()
    end)
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
        RefreshFromQB()
    end)
end

-- === Main loop ===
CreateThread(function()
    ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED, Config.RGBA.LINE.GREEN, Config.RGBA.LINE.BLUE, Config.RGBA.LINE.ALPHA)
    ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED, Config.RGBA.STYLE.GREEN, Config.RGBA.STYLE.BLUE, Config.RGBA.STYLE.ALPHA)
    ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)

    ApplyTextReplacements()
    LoadFrameworkDataBlocking()
    RefreshCached()

    local lastOpen = false

    while true do
        Wait(1)
        local open = IsPauseMenuActive()

        if open and not filterEnabled then
            ApplyFilter(10)
            filterEnabled = true
        elseif (not open) and filterEnabled then
            RemoveFilter()
            filterEnabled = false
        end

        if open then
            -- opportunistically refresh (handles late-loaded phone/job)
            if not lastOpen then RefreshCached() end

            local characterBalance = ("Bank: $%s | Cash: $%s"):format(cached.bank or 0, cached.cash or 0)
            local idAndPhoneNumber = ("ID: %s | Phone: %s"):format(GetPlayerServerId(PlayerId()), cached.phone or "N/A")
            local topRowText = ("%s - %s"):format(cached.name or "Unknown", cached.job or "Unemployed")

            SetScriptGfxDrawBehindPausemenu(true)
            BeginScaleformMovieMethodOnFrontendHeader("SET_HEADING_DETAILS")
            PushScaleformMovieFunctionParameterString(topRowText)
            PushScaleformMovieFunctionParameterString(characterBalance)
            PushScaleformMovieFunctionParameterString(idAndPhoneNumber)
            EndScaleformMovieMethod()
        end

        lastOpen = open
    end
end)
