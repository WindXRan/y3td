package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local attreffect = require 'data.object_tables.attreffect'
local cfg = require 'data.object_tables.outgame_attr_bonus_config'

assert(type(cfg.list) == 'table', 'outgame_attr_bonus_config list should be a table')
assert(type(cfg.by_stage_mode) == 'table', 'outgame_attr_bonus_config by_stage_mode should be a table')
assert(#cfg.list >= 3, 'outgame_attr_bonus_config should keep csv rows')

local challenge_effects = attreffect.by_source.outgame_bonus and attreffect.by_source.outgame_bonus['1-1:challenge']
assert(challenge_effects ~= nil, 'expected outgame challenge rows in attreffect')
assert(challenge_effects.attr['攻击范围'] == 50, 'expected challenge range bonus in attreffect')

assert(cfg.by_stage_mode['1-1'].standard['攻击白字'] == 6, 'standard stage bonus should stay intact')
assert(cfg.by_stage_mode['1-1'].standard['生命白字'] == 120, 'standard stage hp bonus should stay intact')
assert(cfg.by_stage_mode['1-1'].challenge['攻击范围'] == 50, 'challenge stage range bonus should stay intact')

print('[OK] outgame attr bonus config csv loader smoke passed')
