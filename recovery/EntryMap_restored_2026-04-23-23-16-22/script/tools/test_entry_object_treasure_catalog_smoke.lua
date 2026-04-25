package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local catalog = require 'entry_objects.treasure_catalog'

assert(type(catalog) == 'table', 'entry_objects.treasure_catalog should return a table')
assert(type(catalog.by_id) == 'table', 'catalog.by_id should be a table')
assert(type(catalog.sets_by_id) == 'table', 'catalog.sets_by_id should be a table')
assert(catalog.by_id.ITEM_010, 'expected ITEM_010 to exist')
assert(catalog.sets_by_id.set_kill, 'expected set_kill to exist')

print('[OK] entry object treasure catalog smoke passed')
