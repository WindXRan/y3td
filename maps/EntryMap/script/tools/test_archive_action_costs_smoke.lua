package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ArchiveActionCosts = require 'data.tables.outgame.archive_action_costs'

local suit_upgrade = ArchiveActionCosts.get('套装', 'upgrade')
assert(type(suit_upgrade) == 'table', 'expected 套装 upgrade cost config')
assert(suit_upgrade.item_name == '强化石', 'expected 套装 upgrade to consume 强化石')
assert(suit_upgrade.require_stackable_archive_item == true, 'expected upgrade cost to require stackable archive item')
assert(suit_upgrade.base_cost == 100, 'expected 套装 upgrade base cost')
assert(ArchiveActionCosts.get_cost('套装', 'upgrade', 0) == 100, 'expected level 0 suit upgrade cost')
assert(ArchiveActionCosts.get_cost('套装', 'upgrade', 2) == 150, 'expected suit upgrade cost to scale by level')

local source = assert(io.open('maps/EntryMap/script/ui/outgame_archive_shop.lua', 'r'))
local content = source:read('*a')
source:close()

assert(content:find("require 'data.tables.outgame.archive_action_costs'") ~= nil, 'expected archive shop to load action cost config')
assert(content:find('local function get_action_cost_context') ~= nil, 'expected action cost context builder')
assert(content:find('try_pay_action_cost = function') ~= nil, 'expected action cost payment check')
assert(content:find('build_not_enough_message = function') ~= nil, 'expected insufficient resource message')
assert(content:find('local function refresh_action_button_cost') ~= nil, 'expected cost image/text refresh')
assert(content:find('local function find_archive_cost_item') ~= nil, 'expected archive item cost lookup')
assert(content:find('local function spend_archive_item') ~= nil, 'expected archive item cost payment')
assert(content:find("trim_text%(spec%.partition%) == '存档'") ~= nil, 'expected costs to use archive partition items')
assert(content:find("trim_text%(spec%.primary or spec%.l1_tab%) == '仓库'") ~= nil, 'expected costs to use warehouse items')
assert(content:find("string%.format%('%%d/%%d', ctx%.owned or 0, ctx%.cost or 0%)") ~= nil, 'expected cost text to show owned/cost')
assert(content:find("cost_icon = create_child%(root, '图片'%)") ~= nil, 'expected dynamic cost image node inside button root')
assert(content:find("cost_text = create_child%(root, '文本'%)") ~= nil, 'expected dynamic cost text node inside button root')

print('archive action costs smoke passed')
