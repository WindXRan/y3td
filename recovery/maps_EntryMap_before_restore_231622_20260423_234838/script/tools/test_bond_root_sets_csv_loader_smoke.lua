package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.bond_root_sets'

assert(type(mod) == 'table', 'bond_root_sets object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')
assert(#mod.list == 6, 'expected 6 root set metas')

assert(mod.by_id['bond_body_core'], 'expected bond_body_core root set meta')
assert(mod.by_id['bond_body_core'].required_count == 3, 'expected body required_count to be 3')
assert(mod.by_id['bond_body_core'].base_attr['生命'] == 100, 'expected body base hp bonus')
assert(mod.by_id['bond_critical_core'].set_attr['物理暴击'] == 4, 'expected critical set crit bonus')
assert(mod.by_id['bond_growth_core'].set_runtime['strength_on_kill'] == 0.1, 'expected growth set strength_on_kill')

print('[OK] bond root sets csv loader smoke passed')
