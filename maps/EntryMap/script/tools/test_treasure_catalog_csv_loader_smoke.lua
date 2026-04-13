package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local catalog = require 'data.object_tables.treasure_catalog'

assert(type(catalog) == 'table', 'catalog should be a table')
assert(type(catalog.list) == 'table', 'catalog.list should be a table')
assert(type(catalog.by_id) == 'table', 'catalog.by_id should be a table')
assert(type(catalog.sets) == 'table', 'catalog.sets should be a table')
assert(type(catalog.sets_by_id) == 'table', 'catalog.sets_by_id should be a table')

assert(#catalog.list == 22, 'expected 22 treasures')
assert(#catalog.sets == 4, 'expected 4 treasure sets')

local item_004 = catalog.by_id.ITEM_004
assert(item_004, 'expected ITEM_004 to exist')
assert(item_004.name == '暴怒神符', 'expected ITEM_004 name to match')
assert(type(item_004.effects) == 'table' and #item_004.effects == 2, 'expected ITEM_004 to have 2 effects')

local pressure_set = catalog.sets_by_id.set_pressure
assert(pressure_set, 'expected set_pressure to exist')
assert(type(pressure_set.members) == 'table' and #pressure_set.members == 2, 'expected set_pressure to have 2 members')
assert(type(pressure_set.effects) == 'table' and #pressure_set.effects == 1, 'expected set_pressure to have 1 set effect')

print('[OK] treasure catalog csv loader smoke passed')
