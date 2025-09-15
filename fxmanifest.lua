fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'cody-raves'
description 'cr-pause nopixel inspired pause menu'
version '1.0.0'

client_scripts {
    'config.lua',
    'client.lua'
}

files {
    'html/pausemenu.html',
    'html/logo.png',
    'stream/timecycle_cr_pause.xml'   -- <- one path, matches the actual file
}

data_file 'TIMECYCLEMOD_FILE' 'stream/timecycle_cr_pause.xml'  -- <- same path

ui_page 'html/pausemenu.html'
