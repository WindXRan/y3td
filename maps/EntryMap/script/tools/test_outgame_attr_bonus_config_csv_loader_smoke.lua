package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.outgame_attr_bonus_config'

assert(type(cfg.list) == 'table', 'outgame_attr_bonus_config list should be a table')
assert(type(cfg.by_stage_mode) == 'table', 'outgame_attr_bonus_config by_stage_mode should be a table')
assert(#cfg.list >= 3, 'outgame_attr_bonus_config should keep csv rows')
assert(cfg.by_stage_mode['1-1'].standard['攻击白字'] == 6, 'standard stage bonus should stay intact')
assert(cfg.by_stage_mode['1-1'].standard['生命白字'] == 120, 'standard stage hp bonus should stay intact')
assert(cfg.by_stage_mode['1-1'].challenge['攻击范围'] == 50, 'challenge stage range bonus should stay intact')

print('[OK] outgame attr bonus config csv loader smoke passed')
