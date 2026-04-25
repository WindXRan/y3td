package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local evolutions = require 'data.object_tables.evolutions'
local entry_evolutions = require 'entry_objects.evolutions'

assert(type(evolutions) == 'table', 'evolutions module should return a table')
assert(type(evolutions.list) == 'table', 'evolutions.list should be a table')
assert(type(evolutions.by_id) == 'table', 'evolutions.by_id should be a table')
assert(#evolutions.list == 9, 'expected 9 evolutions')

local battle_scar = evolutions.by_id.battle_scar_mark
assert(battle_scar ~= nil, 'battle_scar_mark should exist in evolutions')
assert(battle_scar.name == '战痕进化', 'battle_scar_mark should expose evolution name')

assert(entry_evolutions.by_id.void_mark ~= nil, 'entry_objects.evolutions should expose by_id')
assert(entry_evolutions.by_id.void_mark.name == '虚空进化', 'entry_objects.evolutions should reuse evolution names')

print('evolutions csv loader smoke ok')
