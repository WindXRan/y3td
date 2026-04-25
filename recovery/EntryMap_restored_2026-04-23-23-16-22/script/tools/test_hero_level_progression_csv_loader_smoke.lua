package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.hero_level_progression'

assert(type(cfg) == 'table', 'hero_level_progression should return a table')
assert(type(cfg.list) == 'table', 'hero_level_progression.list should be a table')
assert(type(cfg.by_level) == 'table', 'hero_level_progression.by_level should be a table')
assert(cfg.max_level == 60, 'hero_level_progression max_level should be 60')

local level_1 = cfg.by_level[1]
assert(level_1 ~= nil, 'level 1 progression row should exist')
assert(level_1.exp_to_next == 350, 'level 1 exp_to_next should stay intact')
assert(level_1.all_attr_bonus == 0, 'level 1 all_attr_bonus should start at 0')
assert(level_1.all_element_damage_bonus == 0, 'level 1 all_element_damage_bonus should start at 0')

local level_54 = cfg.by_level[54]
assert(level_54 ~= nil, 'level 54 progression row should exist')
assert(level_54.exp_to_next == 24800, 'level 54 exp_to_next should match provided sequence')
assert(level_54.all_attr_bonus == 1504, 'level 54 all_attr_bonus should match target anchor')
assert(level_54.all_element_damage_bonus == 15.2, 'level 54 all_element_damage_bonus should match target anchor')

local level_10 = cfg.by_level[10]
assert(level_10 ~= nil, 'level 10 progression row should exist')
assert(level_10.all_attr_bonus == 43, 'level 10 all_attr_bonus should use flatter early curve')
assert(level_10.all_element_damage_bonus == 0.4, 'level 10 all_element_damage_bonus should use flatter early curve')

local level_60 = cfg.by_level[60]
assert(level_60 ~= nil, 'level 60 progression row should exist')
assert(level_60.exp_to_next == 0, 'level 60 exp_to_next should be 0')
assert(level_60.all_attr_bonus == 1864, 'level 60 all_attr_bonus should become steeper late')
assert(level_60.all_element_damage_bonus == 18.8, 'level 60 all_element_damage_bonus should become steeper late')

print('[OK] hero level progression csv loader smoke passed')
