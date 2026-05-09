package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'

local suit_buttons = ArchiveTabDefinitions.get_action_buttons('套装')
assert(type(suit_buttons) == 'table' and #suit_buttons == 3, 'expected 套装 to expose 3 action buttons')
assert(suit_buttons[1].label == '佩戴' and suit_buttons[1].action == 'wear', 'expected 套装 first action to be wear')
assert(suit_buttons[2].label == '升级' and suit_buttons[2].action == 'upgrade', 'expected 套装 second action to be upgrade')
assert(suit_buttons[3].label == '随机属性' and suit_buttons[3].action == 'reroll', 'expected 套装 third action to be reroll')

local title_buttons = ArchiveTabDefinitions.get_action_buttons('称号')
assert(type(title_buttons) == 'table' and #title_buttons == 1, 'expected 称号 to expose 1 action button')
assert(title_buttons[1].action == 'wear', 'expected 称号 action to be wear')

local source = assert(io.open('maps/EntryMap/script/ui/outgame_archive_shop.lua', 'r'))
local content = source:read('*a')
source:close()

assert(content:find('local function refresh_action_buttons') ~= nil, 'expected archive action button renderer to exist')
assert(content:find('ArchiveTabDefinitions.get_action_buttons') ~= nil, 'expected action buttons to be driven by archive tab config')
assert(content:find("ACTION_BUTTON_LIST_PATH = ACTION_BUTTON_ROOT_PATH %.%. '%.列表'") ~= nil, 'expected action buttons to bind ArchiveMain.按钮列表.列表')
assert(content:find("create_child%(list, '按钮'%)") ~= nil, 'expected action buttons to add overflow buttons inside the fixed list')
assert(content:find('local function set_z_order') ~= nil, 'expected action buttons to force z order above panels')
assert(content:find('not is_ui_alive%(shop%.action_button_list%)') ~= nil, 'expected action button list lookup to retry when stale')
assert(content:find('create_runtime_action_button') == nil, 'expected action buttons to stop creating ArchivePageTwo runtime prefabs')
assert(content:find("if action == 'upgrade' then") ~= nil, 'expected upgrade action handler')
assert(content:find("if action == 'reroll' then") ~= nil, 'expected reroll action handler')
assert(content:find("if action == 'wear' then") ~= nil, 'expected wear action handler')

print('archive action buttons smoke passed')
