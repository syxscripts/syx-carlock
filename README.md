# syx-carlock

Simple and reliable vehicle locking system for FiveM with **ESX**, **ox_lib**, optional **ox_target**, shared vehicle keys, synchronized lock states, and garage/key-system integrations.

Designed to work with vehicles from garages, dealerships, admin spawns, and other vehicle systems.

## Features

* Vehicle lock / unlock with a configurable keybind
* Default keybind: **L**
* Server-authoritative vehicle lock states
* Lock states synchronized to all players
* ESX `owned_vehicles` ownership checking
* Shared vehicle keys with `/givecarkey`
* `GiveKey` / `RemoveKey` exports for other resources
* Optional **ox_target** vehicle interaction
* Key-fob animation
* Headlight and brake-light flash
* Short horn chirp when locking/unlocking
* Configurable lock distance
* Configurable default vehicle lock state
* Configurable notifications
* Compatible with vehicles spawned by different garage/dealership systems
* **JG Advanced Garages** custom key-system integration
* Server-side exports for controlling vehicle lock states
* No custom SQL table required

## Requirements

| **Resource** | **Needed for**                                  |
| ------------ | ----------------------------------------------- |
| ox_lib       | Notifications and callbacks                     |
| es_extended  | Vehicle ownership and player/key identification |
| oxmysql      | Checking `owned_vehicles`                       |
| ox_target    | Optional vehicle interaction                    |

`ox_target` is optional.

If you do not use `ox_target`, set:

```lua
Config.UseTarget = false
```

in `config/config.lua`.

## Installation

**1. Add the resource**

Drop the `syx-carlock` folder into your server's resources directory.

Add the following to your `server.cfg`:

```cfg
ensure ox_lib
ensure es_extended
ensure syx-carlock
```

If you use `ox_target`, make sure it starts before `syx-carlock`:

```cfg
ensure ox_target
ensure syx-carlock
```

**2. Configure the script**

Open:

```text
syx-carlock/config/config.lua
```

You can configure the keybind, lock distance, ownership requirements, animations, lights, sound, notifications, and target settings.

## How it works

Press **L** near a vehicle to lock or unlock it.

The server checks whether the player:

* Owns the vehicle through the ESX `owned_vehicles` table
* Has been given a shared key
* Has received a key through the `GiveKey` export

When the vehicle state changes, the server broadcasts the new state to all clients so the vehicle is locked or unlocked for everyone nearby.

By default, vehicles are considered locked the first time they are detected:

```lua
Config.DefaultLockedOnSpawn = true
```

## Key Sharing

Players can share access to a nearby vehicle with:

```text
/givecarkey [player id]
```

Example:

```text
/givecarkey 12
```

The player must already have access to the vehicle before they can give another player a key.

Shared keys are stored in memory and are reset when the resource/server restarts.

## Keybind

The default keybind is:

```lua
Config.Keybind = 'L'
```

Players can also change the keybind through:

**Settings → Key Bindings → FiveM → Toggle Vehicle Lock**

The command behind the keybind is:

```text
/carlock
```

## ox_target

If enabled, `syx-carlock` automatically adds a vehicle interaction through `ox_target`.

Configure:

```lua
Config.UseTarget = true
Config.TargetDistance = 2.5
Config.TargetIcon = 'fas fa-lock'
```

The target option allows players to lock or unlock the selected vehicle without using the keybind.

## Vehicle Effects

Locking and unlocking can trigger multiple effects.

### Key-fob animation

```lua
Config.Animation = {
    enabled = true,
    dict = 'anim@mp_player_intmenu@key_fob@',
    clip = 'fob_click',
    duration = 800,
    flag = 48,
}
```

### Vehicle lights

The headlights and brake/tail lights flash when the lock state changes.

```lua
Config.Effects = {
    lights = true,
    duration = 1000,
}
```

### Horn chirp

A short horn sound can be played when the vehicle is locked or unlocked.

```lua
Config.Sound = {
    enabled = true,
    hornDuration = 100,
}
```

All of these effects can be disabled or adjusted in `config/config.lua`.

## Configuration

Main settings:

| **Setting**                   | **What it does**                                    |
| ----------------------------- | --------------------------------------------------- |
| `Config.Keybind`              | Default vehicle lock key                            |
| `Config.LockDistance`         | Maximum distance for finding a vehicle              |
| `Config.RequireOwnership`     | Requires vehicle ownership or a shared key          |
| `Config.DefaultLockedOnSpawn` | Default state for vehicles without a recorded state |
| `Config.UseTarget`            | Enables/disables ox_target                          |
| `Config.TargetDistance`       | ox_target interaction distance                      |
| `Config.TargetIcon`           | ox_target icon                                      |
| `Config.Notify`               | Enables notifications                               |
| `Config.Animation.enabled`    | Enables key-fob animation                           |
| `Config.Effects.lights`       | Enables vehicle light flash                         |
| `Config.Effects.duration`     | Light effect duration                               |
| `Config.Sound.enabled`        | Enables horn chirp                                  |
| `Config.Sound.hornDuration`   | Horn chirp duration                                 |
| `Config.UnlockedOnKeyGiven`   | Unlocks a vehicle when a key is granted             |

## JG Advanced Garages Integration

`syx-carlock` provides `GiveKey` and `RemoveKey` exports so it can be connected to garage systems that support custom vehicle-key integrations.

For **JG Advanced Garages**, open:

```text
jg-advancedgarages/framework/cl-functions.lua
```

Add the following to the vehicle key functions:

```lua
elseif Config.VehicleKeys == "syx-carlock" then
    exports['syx-carlock']:GiveKey(plate)
```

For removing keys:

```lua
elseif Config.VehicleKeys == "syx-carlock" then
    exports['syx-carlock']:RemoveKey(plate)
```

Then configure JG Advanced Garages to use the custom key system:

```lua
Config.VehicleKeys = "syx-carlock"
```

This allows vehicles taken from JG Advanced Garages to automatically receive access through `syx-carlock`.

The same exports can be used by other garage, dealership, valet, or vehicle-management resources.

## Client Exports

### Give a key

```lua
exports['syx-carlock']:GiveKey(plate)
```

Gives the current player access to the vehicle with the specified plate.

### Remove a key

```lua
exports['syx-carlock']:RemoveKey(plate)
```

Removes the current player's shared key for the specified vehicle.

### Check lock state

```lua
local locked = exports['syx-carlock']:IsVehicleLocked(plate)
```

Returns:

```lua
true
```

if locked,

```lua
false
```

if unlocked,

or `nil` if no state is currently known by the client.

## Server Exports

### Check vehicle lock state

```lua
local locked = exports['syx-carlock']:IsVehicleLocked(plate)
```

### Set vehicle lock state

```lua
exports['syx-carlock']:SetVehicleLocked(plate, true, netId)
```

Unlock:

```lua
exports['syx-carlock']:SetVehicleLocked(plate, false, netId)
```

If a network ID is provided, the new state is synchronized to all clients.

## Ownership System

When:

```lua
Config.RequireOwnership = true
```

the script checks the ESX `owned_vehicles` table using:

* Vehicle plate
* Player identifier

Players can also access vehicles through shared/granted keys.

For testing, ownership checking can be disabled:

```lua
Config.RequireOwnership = false
```

This is **not recommended for live servers** because players would be able to lock and unlock vehicles without owning them or having a key.

## Data & Persistence

Vehicle lock states and shared keys are currently stored in server memory.

Shared keys are reset when the resource/server restarts.

No additional SQL table is required.

Vehicle ownership is checked directly through the existing ESX:

```text
owned_vehicles
```

database table.

If persistent shared keys are required, a database table can be added to the key grant/revoke system in `server/main.lua`.

## Resource Structure

```text
syx-carlock/
├── fxmanifest.lua
├── config/
│   └── config.lua
├── client/
│   └── main.lua
├── server/
│   └── main.lua
└── README.md
```

## Compatibility

### Framework

* ESX Legacy

### Libraries

* ox_lib
* oxmysql

### Optional integrations

* ox_target
* JG Advanced Garages
* Custom garage systems
* Dealership systems
* Valet systems
* Other vehicle key systems supporting exports

## Credits

**Syntax Scripts**

`syx-carlock` — Vehicle Lock & Key System

Version: **1.0.0**
