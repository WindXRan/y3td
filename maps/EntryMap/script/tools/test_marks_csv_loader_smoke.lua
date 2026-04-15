package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local marks = require 'data.object_tables.marks'

assert(type(marks) == 'table', 'marks module should return a table')
assert(type(marks.list) == 'table', 'marks.list should be a table')
assert(type(marks.by_id) == 'table', 'marks.by_id should be a table')
assert(#marks.list == 9, 'expected 9 marks')

local battle_scar = marks.by_id.battle_scar_mark
assert(battle_scar ~= nil, 'battle_scar_mark should exist')
assert(battle_scar.quality == 'common', 'battle_scar_mark should keep quality')
assert(battle_scar.pool_weight == 10, 'battle_scar_mark should keep pool_weight')
assert(type(battle_scar.tags) == 'table', 'battle_scar_mark.tags should be a table')
assert(#battle_scar.tags >= 1, 'battle_scar_mark should keep at least one tag')
assert(type(battle_scar.bonuses) == 'table', 'battle_scar_mark.bonuses should be a table')
assert(type(battle_scar.bonuses.runtime) == 'table', 'battle_scar_mark runtime bonuses should be a table')
assert(battle_scar.bonuses.runtime.skill_damage_bonus == 0.12, 'battle_scar_mark runtime bonus should stay intact')

local void_mark = marks.by_id.void_mark
assert(void_mark ~= nil, 'void_mark should exist')
assert(void_mark.bonuses.attack_skill.cooldown_reduction == 0.12, 'void_mark attack_skill bonus should stay intact')

print('marks csv loader smoke ok')
