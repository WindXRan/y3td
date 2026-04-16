package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.gear_upgrade_config'

assert(type(cfg) == 'table', 'gear_upgrade_config should return a table')
assert(type(cfg.slots) == 'table', 'gear_upgrade_config.slots should be a table')
assert(type(cfg.levels_by_level) == 'table', 'gear_upgrade_config.levels_by_level should be a table')

assert(cfg.slots.focus == nil, 'focus slot should be removed')
assert(cfg.slots.emblem == nil, 'emblem slot should be removed')
assert(cfg.slots.weapon.item_key == 134250249, 'weapon item_key should point at the configured growth weapon item')
assert(cfg.slots.weapon.max_level == 100, 'weapon max_level should be 100')
assert(cfg.slots.weapon.affix_choice_count == 3, 'weapon affix_choice_count should be 3')
assert(cfg.levels_by_level[1].gold_cost == 100, 'level 1 cost should stay 100')
assert(cfg.levels_by_level[10].is_affix_node == true, 'level 10 should be an affix node')
assert(cfg.levels_by_level[60].is_affix_node == true, 'level 60 should still be an affix node')
assert(cfg.levels_by_level[100].gold_cost == 550, 'level 100 band cost should be 550')
assert(cfg.levels_by_level[100].is_affix_node == true, 'level 100 should be an affix node')

print('[OK] gear upgrade config csv loader smoke passed')
