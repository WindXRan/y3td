package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'

local warehouse_tip = ArchiveTabDefinitions.get_tip_content('仓库')
assert(type(warehouse_tip) == 'table' and #warehouse_tip >= 8, 'expected 仓库 tip_content to be configured in CSV')
assert(warehouse_tip[1] == '仓库总览', 'expected 仓库 tip title to come from CSV')

local source = assert(io.open('maps/EntryMap/script/ui/outgame_archive_shop.lua', 'r'))
local content = source:read('*a')
source:close()

assert(content:find('set_visible%(tip%.root, in_shop_like_section%)') ~= nil, 'expected archive tip panel visibility to follow shop-like sections')
assert(content:find('refresh_tab_tip%(state, shop, section%)') ~= nil, 'expected archive/shop empty selection to fall back to tab tip content')
assert(content:find("TIP_PANEL_ROOT_PATH = 'ArchiveMain%.提示面板'") ~= nil, 'expected tip panel root to use ArchiveMain.提示面板')
assert(content:find("TIP_PANEL_LIST_PATH = TIP_PANEL_ROOT_PATH %.%. '%.列表'") ~= nil, 'expected tip panel to render into ArchiveMain.提示面板.列表')
assert(content:find("resolve_ui%(player, TIP_PANEL_LIST_PATH%)") ~= nil, 'expected runtime tip resolver to lookup the new list node')
assert(content:find("create_child%(tip%.list, '文本'%)") ~= nil, 'expected tip content text nodes to be created dynamically inside the list')
assert(content:find("set_visible%(resolve_ui%(player, TIP_PANEL_LEGACY_SCROLL_PATH%), false%)") ~= nil, 'expected legacy scrollview tip content to be hidden')
assert(content:find('render_tip_dynamic%(tip,') ~= nil, 'expected tip refresh to use dynamic renderer')

print('archive tip panel smoke passed')
