package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.treasures'

assert(type(mod) == 'table', 'treasures object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')

assert(#mod.list == 22, 'expected 22 compat treasures')

local first_item = mod.list[1]
assert(first_item and first_item.id == 'ITEM_001', 'expected ITEM_001 to remain first treasure')
assert(first_item.order_index == 1, 'expected ITEM_001 order_index to be preserved')

local item_004 = mod.by_id.ITEM_004
assert(item_004, 'expected ITEM_004 to exist')
assert(item_004.order_index == 4, 'expected ITEM_004 order_index to match')
assert(item_004.quality == 'rare', 'expected ITEM_004 quality to match')
assert(item_004.duration_type == 'timed', 'expected ITEM_004 duration_type to match')
assert(item_004.duration and item_004.duration.duration_sec == 30, 'expected ITEM_004 duration_sec to match')
assert(item_004.bonuses.attr['物理暴击'] == 0.50, 'expected ITEM_004 物理暴击 to match')
assert(item_004.bonuses.attr['魔法暴击'] == 0.50, 'expected ITEM_004 魔法暴击 to match')

local item_010 = mod.by_id.ITEM_010
assert(item_010, 'expected ITEM_010 to exist')
assert(item_010.bonuses.runtime['技能免费刷新次数'] == 1, 'expected ITEM_010 skill refresh bonus to match')
assert(item_010.bonuses.runtime['宝物免费刷新次数'] == 1, 'expected ITEM_010 treasure refresh bonus to match')

local set_kill = mod.source_catalog and mod.source_catalog.sets_by_id and mod.source_catalog.sets_by_id.set_kill
assert(set_kill, 'expected set_kill set to exist')
assert(set_kill.order_index == 1, 'expected set_kill order_index to be preserved')

print('[OK] treasures alias compat smoke passed')
