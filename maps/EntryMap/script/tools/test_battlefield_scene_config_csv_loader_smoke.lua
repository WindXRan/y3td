package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.battlefield_scene_config'

assert(type(cfg) == 'table', 'battlefield_scene_config should return a table')
assert(type(cfg.points) == 'table', 'points should be a table')
assert(type(cfg.areas) == 'table', 'areas should be a table')
assert(type(cfg.main_enemy_slow_zones) == 'table', 'main_enemy_slow_zones should be a table')
assert(type(cfg.save_slots) == 'table', 'save_slots should be a table')

assert(cfg.points.hero_spawn.x == -1200, 'hero_spawn.x should stay intact')
assert(cfg.points.defense_point.y == 0, 'defense_point.y should stay intact')

local wave_1_area = cfg.areas.main_spawn_wave_1
assert(type(wave_1_area) == 'table', 'main_spawn_wave_1 should exist')
assert(wave_1_area.x_min == 1660, 'main_spawn_wave_1.x_min should stay intact')
assert(wave_1_area.y_max == 1040, 'main_spawn_wave_1.y_max should stay intact')

assert(#cfg.main_enemy_slow_zones == 3, 'expected 3 slow zones')
assert(cfg.main_enemy_slow_zones[1].area_id == 'mid_slow_lane_outer', 'first slow zone should keep area id')
assert(cfg.main_enemy_slow_zones[2].speed_factor == 0.52, 'second slow zone should keep speed factor')

assert(cfg.save_slots.outgame_profile == 1, 'outgame_profile save slot should stay intact')

print('battlefield_scene_config csv loader smoke ok')
