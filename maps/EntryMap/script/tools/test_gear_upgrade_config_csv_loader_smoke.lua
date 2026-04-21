package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.gear_upgrade_config'

assert(type(cfg) == 'table', 'gear_upgrade_config should return a table')
assert(type(cfg.slots) == 'table', 'gear_upgrade_config.slots should be a table')
assert(type(cfg.levels_by_level) == 'table', 'gear_upgrade_config.levels_by_level should be a table')

assert(cfg.slots.focus == nil, 'focus slot should be removed')
assert(cfg.slots.emblem == nil, 'emblem slot should be removed')
assert(cfg.slots.weapon.item_key == 201390082, 'weapon item_key should point at the configured growth weapon item')
assert(cfg.slots.weapon.weapon_id == 'weapon_default', 'weapon slot should expose the configured weapon id')
assert(cfg.slots.weapon.max_level == 100, 'weapon max_level should be 100')
assert(cfg.slots.weapon.affix_choice_count == 3, 'weapon affix_choice_count should be 3')
assert(cfg.levels_by_level[1].gold_cost == 50, 'level 1 cost should start at 50')
assert(cfg.levels_by_level[1].bonus_pack['攻击'] == 10, 'level 1 should grant 10 attack growth')
assert(cfg.levels_by_level[1].bonus_pack['力量'] == 2, 'level 1 should grant 2 strength growth')
assert(cfg.levels_by_level[1].bonus_pack['敏捷'] == 2, 'level 1 should grant 2 agility growth')
assert(cfg.levels_by_level[1].bonus_pack['智力'] == 2, 'level 1 should grant 2 intelligence growth')
assert(cfg.levels_by_level[10].is_affix_node == true, 'level 10 should be an affix node')
assert(cfg.levels_by_level[10].affix_pool_id == 'pool_10', 'level 10 should point at the first affix pool')
assert(cfg.levels_by_level[60].is_affix_node == true, 'level 60 should still be an affix node')
assert(cfg.levels_by_level[60].affix_pool_id == 'pool_50', 'level 60 should reuse the late game affix pool')
assert(cfg.levels_by_level[100].gold_cost == 5000, 'level 100 upgrade row should keep the linear 5000 gold cost')
assert(cfg.levels_by_level[100].is_affix_node == true, 'level 100 should be an affix node')
assert(cfg.weapons_by_id.weapon_default.weapon_name == '狩猎长弓', 'weapon definition should be loaded')
assert(#cfg.affixes_by_pool.pool_10 == 8, 'pool_10 should load 8 affixes')
assert(cfg.affixes_by_pool.pool_30[5].is_unique == true, 'pool_30 should preserve unique functional affixes')

print('[OK] gear upgrade config csv loader smoke passed')
