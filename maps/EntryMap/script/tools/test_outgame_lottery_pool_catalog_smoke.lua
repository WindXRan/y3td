package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.outgame_lottery_pool_catalog'

assert(cfg.by_id.treasure_hunt_pool_1 ~= nil, 'expected treasure_hunt_pool_1 in lottery catalog')
assert(#cfg.by_id.treasure_hunt_pool_1.list == 54, 'expected 54 items in first treasure hunt lottery pool')
assert(#(cfg.by_id.treasure_hunt_pool_1.by_rarity.N or {}) == 18, 'expected 18 N items')
assert(#(cfg.by_id.treasure_hunt_pool_1.by_rarity.R or {}) == 15, 'expected 15 R items')
assert(#(cfg.by_id.treasure_hunt_pool_1.by_rarity.SR or {}) == 12, 'expected 12 SR items')
assert(#(cfg.by_id.treasure_hunt_pool_1.by_rarity.SSR or {}) == 9, 'expected 9 SSR items')
assert(cfg.items_by_id.ssr_big_joker.summary:find('1200'), 'expected 大王 special summary')
assert(cfg.items_by_id.n_east.source_exchange_points == 100, 'expected N source cost to be 100')

print('outgame lottery pool catalog smoke ok')
