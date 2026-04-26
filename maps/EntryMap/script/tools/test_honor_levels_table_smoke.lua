package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local honor_levels = require 'data.object_tables.honor_levels'

assert(type(honor_levels.list) == 'table', 'honor_levels.list should be a table')
assert(#honor_levels.list >= 20, 'expected honor level table to expose at least 20 rows')

local first = honor_levels.list[1]
assert(first.key == 'honor_level_1', 'expected first honor level key')
assert(first.title == '荣誉1级', 'expected first honor level title')
assert(first.icon == 131360, 'expected honor level icon from table')
assert(first.initial_unlocked == true, 'expected initial unlock flag from table')
assert(first.attr_lines[1] == '生命值 +300', 'expected first attr line to be parsed')
assert(first.attr_lines[2] == '生命成长 +10', 'expected second attr line to be parsed')
assert(honor_levels.by_key.honor_level_20 ~= nil, 'expected by_key lookup for honor level 20')

print('honor levels table smoke ok')
