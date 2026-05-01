package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

y3 = {
  game = {
    is_debug_mode = function()
      return false
    end,
  },
}

local cfg = require 'config.entry_config'

assert(cfg.unit_ids.hero == 134245850, 'entry_config should expose fixed hero unit id')
assert(cfg.temp_unit_labels == nil, 'entry_config should not expose temp unit labels')

print('entry_config battlefield unit wiring ok')
