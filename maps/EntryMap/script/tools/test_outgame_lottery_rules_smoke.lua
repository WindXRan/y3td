package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local rules = require 'data.object_tables.outgame_lottery_pool_rules'

assert(rules.default_pool_id == 'treasure_hunt_pool_1', 'expected default lottery pool id')
assert(rules.by_id.treasure_hunt_pool_1.rates.N == 80, 'expected N rate')
assert(rules.by_id.treasure_hunt_pool_1.rates.R == 13, 'expected R rate')
assert(rules.by_id.treasure_hunt_pool_1.rates.SR == 5, 'expected SR rate')
assert(rules.by_id.treasure_hunt_pool_1.rates.SSR == 2, 'expected SSR rate')
assert(rules.by_id.treasure_hunt_pool_1.first_single_guarantee_rarity == 'SR', 'expected first single guarantee rarity')
assert(rules.by_id.treasure_hunt_pool_1.first_ten_guarantee_rarity == 'SSR', 'expected first ten guarantee rarity')
assert(rules.by_id.treasure_hunt_pool_1.pity_draw_count == 60, 'expected pity draw count')

print('outgame lottery rules smoke ok')
