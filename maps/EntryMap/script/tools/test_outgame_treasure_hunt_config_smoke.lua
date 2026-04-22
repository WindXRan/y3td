package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.outgame_treasure_hunt_config'

assert(cfg.pool_id == 'treasure_hunt_time_labyrinth', 'expected outgame treasure hunt pool id')
assert(cfg.display_name == '夺宝奇兵·时光迷城', 'expected outgame treasure hunt display name')
assert(cfg.currency_name == '夺宝积分', 'expected outgame treasure hunt currency name')
assert(#cfg.list == 27, 'expected full treasure hunt item count')
assert(#(cfg.by_rarity.N or {}) == 19, 'expected N rarity count')
assert(#(cfg.by_rarity.R or {}) == 8, 'expected R rarity count')
assert(cfg.by_id.n_north.initial_owned_count == 1, 'expected 北 to be owned by default')
assert(cfg.by_id.n_center.initial_owned_count == 1, 'expected 中 to be owned by default')
assert(cfg.by_id.n_lollipop.initial_owned_count == 1, 'expected 棒棒糖 to be owned by default')
assert(cfg.by_id.n_flying_dart_attr.initial_owned_count == 1, 'expected 飞镖 to be owned by default')
assert(cfg.by_id.r_spade_a.cost_points == 500, 'expected R rarity cost to be 500')
assert(cfg.by_id.r_century_dukang.effects[2].effect_key == '初始金币', 'expected 百年杜康 gold bonus wiring')

print('outgame treasure hunt config smoke ok')
