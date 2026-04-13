package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.battlefield_unit_config'

assert(type(cfg) == 'table', 'battlefield_unit_config should return a table')
assert(type(cfg.temp_unit_labels) == 'table', 'temp_unit_labels should be a table')
assert(type(cfg.fixed_unit_ids) == 'table', 'fixed_unit_ids should be a table')

assert(cfg.temp_unit_labels.hero == '关羽', 'hero temp label should stay intact')
assert(cfg.temp_unit_labels.wave_5_boss == '赵云', 'wave_5_boss temp label should stay intact')
assert(cfg.temp_unit_labels.treasure_trial_guard == '刘备', 'treasure_trial_guard temp label should stay intact')

assert(cfg.fixed_unit_ids.hero == 134274912, 'hero unit id should stay intact')

print('battlefield_unit_config csv loader smoke ok')
