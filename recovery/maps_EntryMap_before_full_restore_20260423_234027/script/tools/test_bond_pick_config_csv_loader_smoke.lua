package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local config = require 'data.object_tables.bond_pick_config'

assert(type(config) == 'table', 'bond pick config should be a table')
assert(config.choice_count == 3, 'expected choice_count to be 3')
assert(config.include_group_choices == true, 'expected include_group_choices to be true')
assert(type(config.weights) == 'table', 'weights should be a table')
assert(config.weights.node == 1, 'expected node base weight to be 1')
assert(config.weights.group == 1, 'expected group base weight to be 1')

print('[OK] bond pick config csv loader smoke passed')
