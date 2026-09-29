Config = {}

-- ═══════════════════════════════════════════
--  GENERAL
-- ═══════════════════════════════════════════

-- Default keybind. Players can rebind it themselves in
-- Settings > Key Bindings > FiveM > "Toggle Vehicle Lock".
Config.Keybind = 'L'

-- Max distance (in game units) from the player to the vehicle
-- for the keybind to find and target it.
Config.LockDistance = 5.0

-- If true, a player must own the vehicle (ESX owned_vehicles) or
-- have been given a key (shared key / GiveKey export) to lock/unlock it.
-- Set to false only for testing - NOT recommended on a live server.
Config.RequireOwnership = true

-- Whether a vehicle is locked by default the first time syx-carlock
-- sees it (i.e. no lock state has been recorded yet for that plate).
Config.DefaultLockedOnSpawn = true

-- ═══════════════════════════════════════════
--  TARGET (ox_target)
-- ═══════════════════════════════════════════

Config.UseTarget = true
Config.TargetDistance = 2.5
Config.TargetIcon = 'fas fa-lock'

-- ═══════════════════════════════════════════
--  NOTIFICATIONS (ox_lib)
-- ═══════════════════════════════════════════

Config.Notify = true

Config.Locales = {
    locked = 'Vehicle locked',
    unlocked = 'Vehicle unlocked',
    no_vehicle = 'No vehicle nearby',
    no_permission = 'You don\'t have keys to this vehicle',
    key_given = 'You gave a key to %s',
    key_revoked = 'Key revoked',
    key_received = 'You were given a key to this vehicle',
    not_in_or_near_vehicle = 'You need to be in or near the vehicle',
    target_lock = 'Lock vehicle',
    target_unlock = 'Unlock vehicle',
}

-- ═══════════════════════════════════════════
--  ANIMATION (key fob raise / click)
-- ═══════════════════════════════════════════

Config.Animation = {
    enabled = true,
    dict = 'anim@mp_player_intmenu@key_fob@',
    clip = 'fob_click',
    duration = 800, -- ms
    flag = 48,      -- upper body only, doesn't interrupt walking
}

-- ═══════════════════════════════════════════
--  VEHICLE FX (lights / siren flash)
-- ═══════════════════════════════════════════

Config.Effects = {
    lights = true,
    duration = 1000, -- ms the headlights + tail/brake lights stay on
}

-- ═══════════════════════════════════════════
--  SOUND (quick horn chirp, like a real remote lock)
-- ═══════════════════════════════════════════

Config.Sound = {
    enabled = true,
    hornDuration = 100, -- ms - keep this short, it's a "chirp" not a honk
}

-- ═══════════════════════════════════════════
--  GARAGE / KEY-SYSTEM INTEGRATION
-- ═══════════════════════════════════════════
-- syx-carlock exposes client exports GiveKey(plate) / RemoveKey(plate)
-- so that other scripts (garages, dealerships, etc.) can grant/remove
-- access the same way they do for wasabi_carlock, qs-vehiclekeys, etc.
-- See README.md -> "JG Advanced Garages integration" for the exact
-- snippet to paste into jg-advancedgarages/framework/cl-functions.lua.

-- Whether a vehicle that syx-carlock just received a GiveKey() call for
-- (e.g. freshly taken out of a garage) should spawn unlocked.
Config.UnlockedOnKeyGiven = true
