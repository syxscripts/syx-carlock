local ESX = exports['es_extended']:getSharedObject()

-- plate -> bool, client-side cache of the last known lock state
-- (authoritative state always lives server-side, this is just for FX/UI)
local knownStates = {}

local isBusy = false

-- ───────────────────────────────────────────
--  HELPERS
-- ───────────────────────────────────────────

local function normalizePlate(plate)
    if not plate then return nil end
    return string.upper(string.gsub(plate, '%s+', ''))
end

local function notify(msg, type)
    if not Config.Notify then return end
    if GetResourceState('ox_lib') == 'started' then
        lib.notify({ description = msg, type = type or 'inform' })
    else
        -- fallback if ox_lib notify isn't available for some reason
        TriggerEvent('chat:addMessage', { args = { 'Carlock', msg } })
    end
end

-- Finds the closest vehicle to the player within maxDistance.
-- Works with ANY vehicle entity that currently exists client-side,
-- regardless of which garage/dealership script spawned it.
local function getClosestVehicle(maxDistance)
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')

    local closestVehicle, closestDistance = nil, maxDistance

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if DoesEntityExist(vehicle) then
            local vCoords = GetEntityCoords(vehicle)
            local dist = #(pCoords - vCoords)
            if dist < closestDistance then
                closestVehicle = vehicle
                closestDistance = dist
            end
        end
    end

    return closestVehicle, closestDistance
end

-- ───────────────────────────────────────────
--  FX: animation, lights, sound
-- ───────────────────────────────────────────

local function playKeyFobAnim()
    if not Config.Animation.enabled then return end

    local ped = PlayerPedId()
    local dict = Config.Animation.dict

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasAnimDictLoaded(dict) then return end

    TaskPlayAnim(ped, dict, Config.Animation.clip, 8.0, -8.0, Config.Animation.duration, Config.Animation.flag, 0, false, false, false)
end

-- Turns the headlights and tail/brake lights on for Config.Effects.duration,
-- then hands control back to the game (headlights: automatic, brake lights: off).
local function flashVehicleLights(vehicle)
    if not Config.Effects.lights then return end
    if not DoesEntityExist(vehicle) then return end

    CreateThread(function()
        SetVehicleLights(vehicle, 2)       -- 2 = force headlights on
        SetVehicleBrakeLights(vehicle, true) -- forces the tail/brake lights on

        Wait(Config.Effects.duration)

        if DoesEntityExist(vehicle) then
            SetVehicleLights(vehicle, 0)   -- 0 = automatic control
            SetVehicleBrakeLights(vehicle, false)
        end
    end)
end

local function playLockChirp(vehicle)
    if not Config.Sound.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    -- SetHornPermanentlyOnTime sounds the horn for the given duration (ms).
    -- With an empty driver's seat (our case - the vehicle is parked/locked)
    -- it plays for the full duration, giving a short "chirp" effect.
    SetHornPermanentlyOnTime(vehicle, Config.Sound.hornDuration + 0.0)
end

local function applyVehicleFX(vehicle, locked)
    playKeyFobAnim()
    flashVehicleLights(vehicle)
    playLockChirp(vehicle)
end

-- ───────────────────────────────────────────
--  CORE: toggle lock
-- ───────────────────────────────────────────

local function applyDoorState(vehicle, locked)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleDoorsLocked(vehicle, locked and 2 or 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, locked)
end

-- Fires on EVERY client when a lock state changes, so doors actually
-- lock/unlock for everyone near the car, not just the person who pressed L.
RegisterNetEvent('syx-carlock:client:setLockState', function(netId, plate, locked)
    plate = normalizePlate(plate)
    knownStates[plate] = locked

    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    applyDoorState(vehicle, locked)
end)

local function toggleVehicleLock(vehicle)
    if isBusy then return end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(Config.Locales.no_vehicle, 'error')
        return
    end

    isBusy = true

    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    local locked = lib.callback.await('syx-carlock:toggleLock', false, plate, netId)

    if locked == nil then
        notify(Config.Locales.no_permission, 'error')
        isBusy = false
        return
    end

    applyDoorState(vehicle, locked)
    applyVehicleFX(vehicle, locked)
    notify(locked and Config.Locales.locked or Config.Locales.unlocked, locked and 'error' or 'success')

    isBusy = false
end

local function tryToggleNearestVehicle()
    local vehicle = getClosestVehicle(Config.LockDistance)
    toggleVehicleLock(vehicle)
end

-- ───────────────────────────────────────────
--  KEYBIND
-- ───────────────────────────────────────────

RegisterKeyMapping('carlock', 'Toggle Vehicle Lock', 'keyboard', Config.Keybind)
RegisterCommand('carlock', function()
    tryToggleNearestVehicle()
end, false)

-- ───────────────────────────────────────────
--  ox_target INTEGRATION
-- ───────────────────────────────────────────

CreateThread(function()
    if not Config.UseTarget then return end

    local timeout = GetGameTimer() + 5000
    while GetResourceState('ox_target') ~= 'started' and GetGameTimer() < timeout do
        Wait(100)
    end
    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:addGlobalVehicle({
        {
            name = 'syx-carlock:target',
            icon = Config.TargetIcon,
            label = Config.Locales.target_lock .. ' / ' .. Config.Locales.target_unlock,
            distance = Config.TargetDistance,
            onSelect = function(data)
                toggleVehicleLock(data.entity)
            end,
        },
    })
end)

-- ───────────────────────────────────────────
--  KEY SHARING (used by /givecarkey and by other scripts)
-- ───────────────────────────────────────────

RegisterNetEvent('syx-carlock:client:keyReceived', function()
    notify(Config.Locales.key_received, 'success')
end)

RegisterCommand('givecarkey', function(_, args)
    local targetId = tonumber(args[1])
    if not targetId then
        notify('Usage: /givecarkey [player id]', 'error')
        return
    end

    local vehicle = getClosestVehicle(Config.LockDistance)
    if not vehicle or not DoesEntityExist(vehicle) then
        notify(Config.Locales.no_vehicle, 'error')
        return
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    TriggerServerEvent('syx-carlock:server:shareKey', targetId, plate)
end, false)

-- ───────────────────────────────────────────
--  EXPORTS (for other resources, e.g. jg-advancedgarages)
-- ───────────────────────────────────────────
-- These mirror the shape officially-supported key scripts use
-- (e.g. exports.wasabi_carlock:GiveKey(plate)) so syx-carlock can be
-- wired into jg-advancedgarages' custom key system. See README.md.

exports('GiveKey', function(plate)
    plate = normalizePlate(plate)
    if not plate then return end
    TriggerServerEvent('syx-carlock:server:grantKey', plate)
end)

exports('RemoveKey', function(plate)
    plate = normalizePlate(plate)
    if not plate then return end
    TriggerServerEvent('syx-carlock:server:revokeKey', plate)
end)

exports('IsVehicleLocked', function(plate)
    plate = normalizePlate(plate)
    return knownStates[plate]
end)
