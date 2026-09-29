fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Syntax Scripts (script name: syx-carlock)'
description 'syx-carlock - Simple ESX/ox_lib vehicle locking system, compatible with jg-advancedgarages and other garages'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

-- ox_target is optional (see config.lua -> Config.UseTarget). If you don't
-- run ox_target, set Config.UseTarget = false and remove it from here/deps.
dependencies {
    'ox_lib',
    'es_extended'
}
