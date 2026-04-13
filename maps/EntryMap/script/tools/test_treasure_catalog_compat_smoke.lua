package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local compat = require 'data.object_tables.treasure_catalog_compat'

assert(type(compat) == 'table', 'compat should be a table')
assert(type(compat.list) == 'table', 'compat.list should be a table')
assert(type(compat.by_id) == 'table', 'compat.by_id should be a table')
assert(#compat.list == 22, 'expected 22 compat treasures')

local item_004 = compat.by_id.ITEM_004
assert(item_004, 'expected ITEM_004 to exist')
assert(item_004.quality == 'rare', 'expected ITEM_004 quality to map to rare')
assert(item_004.treasure_type == 'tactical_temp', 'expected ITEM_004 to map to tactical_temp')
assert(item_004.duration_type == 'timed', 'expected ITEM_004 duration_type to map to timed')
assert(item_004.duration and item_004.duration.duration_sec == 30, 'expected ITEM_004 duration_sec to be 30')
assert(item_004.bonuses.attr['物理暴击'] == 0.50, 'expected ITEM_004 物理暴击 to map to attr pack')
assert(item_004.bonuses.attr['魔法暴击'] == 0.50, 'expected ITEM_004 魔法暴击 to map to attr pack')

local item_006 = compat.by_id.ITEM_006
assert(item_006 and item_006.bonuses and item_006.bonuses.runtime, 'expected ITEM_006 bonuses.runtime')
assert(item_006.bonuses.runtime['立即金币'] == 20000, 'expected ITEM_006 立即金币 to map to 20000')

local item_010 = compat.by_id.ITEM_010
assert(item_010 and item_010.bonuses and item_010.bonuses.runtime, 'expected ITEM_010 bonuses.runtime')
assert(item_010.bonuses.runtime['技能免费刷新次数'] == 1, 'expected ITEM_010 技能免费刷新次数 to map to 1')
assert(item_010.bonuses.runtime['英雄免费刷新次数'] == 1, 'expected ITEM_010 英雄免费刷新次数 to map to 1')
assert(item_010.bonuses.runtime['宝物免费刷新次数'] == 1, 'expected ITEM_010 宝物免费刷新次数 to map to 1')

local item_014 = compat.by_id.ITEM_014
assert(item_014 and item_014.bonuses and item_014.bonuses.runtime, 'expected ITEM_014 bonuses.runtime')
assert(item_014.bonuses.runtime['木材翻倍'] == 1.00, 'expected ITEM_014 木材翻倍 to map to 1.00')
assert(item_014.bonuses.runtime['木材清零'] == 1, 'expected ITEM_014 木材清零 to map to 1')

local item_015 = compat.by_id.ITEM_015
assert(item_015 and item_015.bonuses and item_015.bonuses.attr, 'expected ITEM_015 bonuses.attr')
assert(item_015.bonuses.attr['魔法暴伤'] == 0.20, 'expected ITEM_015 魔法暴伤 to map to 0.20')

print('[OK] treasure catalog compat smoke passed')
