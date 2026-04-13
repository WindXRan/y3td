package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.battle_base_config'

assert(type(cfg) == 'table', 'battle_base_config should return a table')
assert(type(cfg.hero_init_stats) == 'table', 'hero_init_stats should still be embedded')
assert(type(cfg.global_rules) == 'table', 'global_rules should remain a table')
assert(type(cfg.progression_rules) == 'table', 'progression_rules should remain a table')
assert(type(cfg.resource_rules) == 'table', 'resource_rules should remain a table')
assert(type(cfg.challenge_rules) == 'table', 'challenge_rules should remain a table')
assert(type(cfg.global_rules.player_id) == 'number', 'player_id should remain numeric')
assert(type(cfg.challenge_rules.recover_sec) == 'number', 'recover_sec should remain numeric')
assert(cfg.debug_apply_hero_bonus_on_spawn == false, 'debug_apply_hero_bonus_on_spawn should remain false')
assert(cfg.resource_rules.initial_wood == 150, 'initial_wood should stay intact')

print('battle_base_config csv loader smoke ok')
