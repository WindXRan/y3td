package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local config = require 'data.object_tables.bond_draw_config'

assert(type(config) == 'table', 'bond draw config should be a table')
assert(config.draw_cost == 100, 'expected draw_cost to be 100')
assert(type(config.refresh_costs) == 'table', 'refresh_costs should be a table')
assert(config.refresh_costs[1] == 40, 'expected first refresh cost to be 40')
assert(config.refresh_costs[2] == 80, 'expected second refresh cost to be 80')
assert(config.refresh_costs[3] == 100, 'expected third refresh cost to be 100')
assert(type(config.group_choice_order) == 'table', 'group_choice_order should be a table')
assert(#config.group_choice_order == 6, 'expected 6 group choices')
assert(type(config.group_choice_defs) == 'table', 'group_choice_defs should be a table')
assert(config.group_choice_defs.body.display_name == '体术', 'expected body group display_name')
assert(type(config.group_choice_defs.body.path_texts) == 'table', 'expected body path_texts')
assert(#config.group_choice_defs.body.path_texts == 3, 'expected 3 body chain paths')
assert(config.group_choice_defs.body.path_texts[1] == '生命 -> 血誓 / 血魔', 'expected first body chain path')
assert(config.group_choice_defs.body.desc == '解锁：生命 -> 血誓 / 血魔；战术；固守 -> 陷阵', 'expected body group chain desc')
assert(config.group_choice_defs.archery.desc == '解锁：广射 -> 月刃；速攻；射术 -> 多重箭', 'expected archery group chain desc')
assert(config.group_choice_defs.growth.quality == 'rare', 'expected growth group quality')
assert(#config.group_choice_defs.growth.path_texts == 3, 'expected 3 growth chain paths')
assert(config.group_choice_defs.growth.desc == '解锁：敏捷 -> 猎魔人 -> 弓神；力量 -> 野蛮人 -> 战神；智力 -> 秘法师 -> 法神', 'expected growth group chain desc')

print('[OK] bond draw config csv loader smoke passed')
