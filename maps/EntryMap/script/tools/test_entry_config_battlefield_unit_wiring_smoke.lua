package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

y3 = {
  game = {
    is_debug_mode = function()
      return false
    end,
  },
}

local cfg = require 'config.entry_config'

assert(cfg.unit_ids.hero == 201390301, 'entry_config should expose csv-backed hero unit id')
assert(cfg.temp_unit_labels.wave_3_boss == '黄月英', 'entry_config should expose csv-backed temp unit labels')
assert(cfg.temp_unit_labels.treasure_trial_guard == '刘备', 'entry_config should expose csv-backed treasure trial guard label')

print('entry_config battlefield unit wiring ok')
