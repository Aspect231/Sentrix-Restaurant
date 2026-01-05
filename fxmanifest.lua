fx_version 'adamant'
game 'gta5'
lua54 'yes'

author 'Aspect'
description '[SENTRIX] Restaurant'

server_scripts {
    'config.lua',
    'src/shared/**.lua',
    'src/server/**.lua',
    '@mysql-async/lib/MySQL.lua'
}

client_scripts {
    'config.lua',
    'src/shared/**.lua',
    'src/client/**.lua'
}

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target'
}

escrow_ignore {
    'config.lua'
}
