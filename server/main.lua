local ESX = exports['es_extended']:getSharedObject()

-- plate -> bool (true = locked). Authoritative lock state.
local VehicleStates = {}

-- plate -> { [identifier] = true }. In-memory shared/granted keys.
-- NOTE: this resets on server restart, same as most lightweight carlock
-- scripts. If you want keys to survive restarts, extend grantKey/revokeKey
-- below to also read/write a database table (see README.md for a ready
-- to use `syx_carlock_keys` SQL table you can wire in).
local SharedKeys = {}

local function normalizePlate(plate)
    if not plate then return nil end
    return string.upper(string.gsub(plate, '%s+', ''))
end

-- ───────────────────────────────────────────
--  OWNERSHIP CHECK (ESX owned_vehicles)
-- ───────────────────────────────────────────

local function isOwner(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local result = MySQL.scalar.await(
        'SELECT 1 FROM owned_vehicles WHERE plate = ? AND owner = ? LIMIT 1',
        { plate, xPlayer.identifier }
    )

    return result ~= nil
end

local function hasSharedKey(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    if not SharedKeys[plate] then return false end
    return SharedKeys[plate][xPlayer.identifier] == true
end

local function canAccessVehicle(source, plate)
    if not Config.RequireOwnership then return true end
    return isOwner(source, plate) or hasSharedKey(source, plate)
end

-- ───────────────────────────────────────────
--  TOGGLE LOCK
-- ───────────────────────────────────────────

lib.callback.register('syx-carlock:toggleLock', function(source, plate, netId)
    plate = normalizePlate(plate)
    if not plate then return nil end

    if not canAccessVehicle(source, plate) then
        return nil
    end

    if VehicleStates[plate] == nil then
        VehicleStates[plate] = Config.DefaultLockedOnSpawn
    end

    VehicleStates[plate] = not VehicleStates[plate]

    -- Sync to every client so the vehicle actually locks/unlocks for
    -- everyone standing nearby, not just the player who pressed the key.
    TriggerClientEvent('syx-carlock:client:setLockState', -1, netId, plate, VehicleStates[plate])

    return VehicleStates[plate]
end)

-- ───────────────────────────────────────────
--  KEY SHARING
-- ───────────────────────────────────────────

RegisterNetEvent('syx-carlock:server:shareKey', function(targetId, plate)
    local src = source
    plate = normalizePlate(plate)
    if not plate then return end

    -- Only the owner (or someone who already holds a key) can share one.
    if not canAccessVehicle(src, plate) then return end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then return end

    SharedKeys[plate] = SharedKeys[plate] or {}
    SharedKeys[plate][target.identifier] = true

    TriggerClientEvent('syx-carlock:client:keyReceived', targetId)

    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', src, {
            description = string.format(Config.Locales.key_given, target.getName and target.getName() or ('id ' .. targetId)),
            type = 'success',
        })
    end
end)

-- ───────────────────────────────────────────
--  GARAGE / KEY-SYSTEM INTEGRATION
-- ───────────────────────────────────────────
-- These two events are triggered by the client exports GiveKey()/RemoveKey()
-- so other resources (jg-advancedgarages, dealerships, valet scripts, etc.)
-- can grant or revoke access the same way they do for other key scripts.

RegisterNetEvent('syx-carlock:server:grantKey', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    plate = normalizePlate(plate)
    if not plate then return end

    SharedKeys[plate] = SharedKeys[plate] or {}
    SharedKeys[plate][xPlayer.identifier] = true

    -- A vehicle that's just been handed keys (e.g. pulled out of a garage)
    -- typically shouldn't be locked yet.
    if Config.UnlockedOnKeyGiven then
        VehicleStates[plate] = false
    end
end)

RegisterNetEvent('syx-carlock:server:revokeKey', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    plate = normalizePlate(plate)
    if not plate then return end

    if SharedKeys[plate] then
        SharedKeys[plate][xPlayer.identifier] = nil
    end
end)

-- ───────────────────────────────────────────
--  EXPORTS (for other server-side resources)
-- ───────────────────────────────────────────

exports('IsVehicleLocked', function(plate)
    plate = normalizePlate(plate)
    return VehicleStates[plate]
end)

exports('SetVehicleLocked', function(plate, locked, netId)
    plate = normalizePlate(plate)
    if not plate then return end
    VehicleStates[plate] = locked and true or false
    if netId then
        TriggerClientEvent('syx-carlock:client:setLockState', -1, netId, plate, VehicleStates[plate])
    end
end)
