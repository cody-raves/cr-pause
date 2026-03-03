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

-- === Background / Filter ===
local overlayOpacity = 0.0

local function ApplyHudColors()
    ReplaceHudColourWithRgba(116, Config.RGBA.LINE.RED, Config.RGBA.LINE.GREEN, Config.RGBA.LINE.BLUE, Config.RGBA.LINE.ALPHA)
    ReplaceHudColourWithRgba(117, Config.RGBA.STYLE.RED, Config.RGBA.STYLE.GREEN, Config.RGBA.STYLE.BLUE, Config.RGBA.STYLE.ALPHA)
    ReplaceHudColourWithRgba(142, Config.RGBA.WAYPOINT.RED, Config.RGBA.WAYPOINT.GREEN, Config.RGBA.WAYPOINT.BLUE, Config.RGBA.WAYPOINT.ALPHA)
end

local function ToggleLogo(show)
    if Config.DisplayLogo then
        SendNUIMessage({ display = show })
    end
end


-- === Pause-menu Map Tab Detection ===
-- Debug notes:
--  - When enabled, we ONLY print when the pause selection changes (no spam).
--  - This lets you click tabs and capture the MAP tab ids cleanly.
local _lastSelMenuId, _lastSelUniqueId = nil, nil
local _lastDbgAt = 0
local _lastFallbackMapState = nil
local _lastPauseState = nil

local function _dbg_once_on_change(menuId, uniqueId, extra)
    if not Config.DebugPauseSelection then return end

    -- Only print on selection change
    if menuId == _lastSelMenuId and uniqueId == _lastSelUniqueId then return end
    _lastSelMenuId, _lastSelUniqueId = menuId, uniqueId

    -- Throttle in case it flaps rapidly
    local now = GetGameTimer()
    if now - _lastDbgAt < 150 then return end
    _lastDbgAt = now

    if extra and extra ~= "" then
        print(("[cr-pause] Pause selection changed -> menuId=%s uniqueId=%s | %s"):format(
            tostring(menuId), tostring(uniqueId), tostring(extra)
        ))
    else
        print(("[cr-pause] Pause selection changed -> menuId=%s uniqueId=%s"):format(
            tostring(menuId), tostring(uniqueId)
        ))
    end
end

local function _dbg_info(msg)
    if Config.DebugPauseSelection and Config.DebugPauseVerbose then
        print("[cr-pause] " .. msg)
    end
end

local function _dbg_state_once_on_change(state)
    if not Config.DebugPauseSelection then return end
    if state == _lastPauseState then return end
    _lastPauseState = state
    print(("[cr-pause] Pause state changed -> state=%s"):format(tostring(state)))
end

local function GetPauseMenuSelectionIds()
    if not Citizen or not Citizen.InvokeNative then
        _dbg_info("Citizen.InvokeNative missing")
        return nil, nil
    end
    if not Citizen.PointerValueIntInitialized then
        _dbg_info("Citizen.PointerValueIntInitialized missing (your artifact may not support out-params in Lua this way)")
        return nil, nil
    end
    if not Citizen.PointerValueInt then
        _dbg_info("Citizen.PointerValueInt missing")
        return nil, nil
    end

    local menuPtr = Citizen.PointerValueIntInitialized(0)
    local uniquePtr = Citizen.PointerValueIntInitialized(0)

    local ok = pcall(function()
        Citizen.InvokeNative(0x36C1451A88A09630, menuPtr, uniquePtr) -- _GET_PAUSE_MENU_SELECTION
    end)
    if not ok then
        _dbg_info("_GET_PAUSE_MENU_SELECTION invoke failed")
        return nil, nil
    end

    local menuId, uniqueId
    local ok2 = pcall(function() menuId = Citizen.PointerValueInt(menuPtr) end)
    local ok3 = pcall(function() uniqueId = Citizen.PointerValueInt(uniquePtr) end)
    if not ok2 or not ok3 then
        _dbg_info("PointerValueInt read failed")
        return nil, nil
    end

    return menuId, uniqueId
end

local function GetPauseMenuSelectionIdsAlt()
    local ok, a, b = pcall(function()
        return GetPauseMenuSelection()
    end)
    if not ok then return nil, nil end
    if type(a) == "number" and type(b) == "number" then
        return a, b
    end
    return nil, nil
end

local function GetPauseMenuStateSafe()
    local ok, state = pcall(function()
        return GetPauseMenuState()
    end)
    if ok then return state end
    return nil
end

local function IsPauseMapTabOpen()
    if not IsPauseMenuActive() then
        _lastFallbackMapState = nil
        _lastPauseState = nil
        return false
    end

    local state = GetPauseMenuStateSafe()
    _dbg_state_once_on_change(state)
    if type(state) == "number" and state == (Config.PauseMapState or 2) then
        return true
    end

    local menuId, uniqueId = GetPauseMenuSelectionIds()
    if type(menuId) ~= "number" or type(uniqueId) ~= "number" then
        menuId, uniqueId = GetPauseMenuSelectionIdsAlt()
    end
    if type(menuId) == "number" and type(uniqueId) == "number" then
        _dbg_once_on_change(menuId, uniqueId)
        _lastFallbackMapState = nil
        return (menuId == (Config.PauseMapMenuId or 0) and uniqueId == (Config.PauseMapUniqueId or 0))
    end

    _dbg_info("Pause selection ids unavailable; using fallback (if enabled)")
    if Config.FallbackUseBigmapActive ~= false then
        local ok4, res = pcall(function() return IsBigmapActive() end)
        if ok4 then
            if Config.DebugPauseSelection and _lastFallbackMapState ~= res then
                print(("[cr-pause] Fallback map state changed -> %s"):format(tostring(res)))
                _lastFallbackMapState = res
            end
            return res
        end
        local ok5, res5 = pcall(function() return Citizen.InvokeNative(0xFFF65C63) end) -- IS_BIGMAP_ACTIVE
        if ok5 then
            local mapOpen = (res5 == true)
            if Config.DebugPauseSelection and _lastFallbackMapState ~= mapOpen then
                print(("[cr-pause] Fallback map state changed -> %s"):format(tostring(mapOpen)))
                _lastFallbackMapState = mapOpen
            end
            return mapOpen
        end
    end

    return false
end

CreateThread(function()
    ToggleLogo(false)
end)


local function ApplyFilter(steps)
    local step = 1.0 / steps
    local opacity = 0.0

    if Config.UseCustomFilter then
        SetTimecycleModifier(Config.CustomTimeCycleModifier)
    else
        SetNightvision(true)
    end

    ApplyHudColors()

    while opacity <= 1.0 do
        SetTimecycleModifierStrength(opacity)
        opacity = opacity + step
        Wait(1)
    end
end

local function RemoveFilter()
    if Config.UseCustomFilter then
        ClearTimecycleModifier()
    else
        SetNightvision(false)
    end
end

local function ApplyColorOverlay(steps)
    ApplyHudColors()

    local step = 1.0 / steps
    overlayOpacity = 0.0

    while overlayOpacity < 1.0 do
        overlayOpacity = overlayOpacity + step
        Wait(1)
    end

    overlayOpacity = 1.0
end

local function RemoveColorOverlay(steps)
    local step = 1.0 / steps

    while overlayOpacity > 0.0 do
        overlayOpacity = overlayOpacity - step
        Wait(1)
    end

    overlayOpacity = 0.0
end

-- Draw overlay behind the pause menu (only active when BackgroundMode = "color")
CreateThread(function()
    while true do
        if (Config.BackgroundMode == "color") and overlayOpacity > 0.0 and IsPauseMenuActive() then
            local c = Config.BackgroundColor or { RED = 0, GREEN = 0, BLUE = 0, ALPHA = 160 }
            SetScriptGfxDrawBehindPausemenu(true)
            DrawRect(0.5, 0.5, 1.0, 1.0,
                c.RED or 0,
                c.GREEN or 0,
                c.BLUE or 0,
                math.floor((c.ALPHA or 160) * overlayOpacity)
            )
        end
        Wait(0)
    end
end)

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
local lastLogoState = nil

    while true do
        Wait(1)
        local open = IsPauseMenuActive()

        if open and not filterEnabled then
            local steps = Config.BackgroundFadeSteps or 10
            local mode = (Config.BackgroundMode or "filter")

            -- Make sure we start from a clean slate
            RemoveFilter()
            overlayOpacity = 0.0

            if mode == "filter" then
                ApplyFilter(steps)
            elseif mode == "color" then
                ApplyColorOverlay(steps)
            elseif mode == "none" then
                ApplyHudColors()
            else
                -- fallback
                ApplyFilter(steps)
            end

            local shouldShowLogo = (not IsPauseMapTabOpen())
            ToggleLogo(shouldShowLogo)
            lastLogoState = shouldShowLogo
            filterEnabled = true
        elseif (not open) and filterEnabled then
            local steps = Config.BackgroundFadeSteps or 10
            local mode = (Config.BackgroundMode or "filter")

            if mode == "filter" then
                RemoveFilter()
            elseif mode == "color" then
                RemoveColorOverlay(steps)
                RemoveFilter()
            else
                RemoveFilter()
                overlayOpacity = 0.0
            end

            ToggleLogo(false)
            lastLogoState = false
            filterEnabled = false
        end

        if open then
            -- Keep logo synced with Map tab state while pause is open
            local shouldShowLogo = (not IsPauseMapTabOpen())
            if lastLogoState == nil or shouldShowLogo ~= lastLogoState then
                ToggleLogo(shouldShowLogo)
                lastLogoState = shouldShowLogo
            end

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
