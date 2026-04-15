package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

y3 = {
  game = {
    is_debug_mode = function()
      return false
    end,
  },
}

local cfg = require 'config.entry_config'

assert(cfg.points.hero_spawn.x == -1200, 'entry_config should expose csv-backed hero spawn')
assert(cfg.points.defense_point.y == 0, 'entry_config should expose csv-backed defense point')
assert(cfg.areas.challenge_spawn_top.y_min == 220, 'entry_config should expose csv-backed areas')
assert(cfg.main_enemy_slow_zones[3].speed_factor == 0.38, 'entry_config should expose csv-backed slow zones')
assert(cfg.save_slots.outgame_profile == 1, 'entry_config should expose csv-backed save slots')

print('entry_config battlefield scene wiring ok')
