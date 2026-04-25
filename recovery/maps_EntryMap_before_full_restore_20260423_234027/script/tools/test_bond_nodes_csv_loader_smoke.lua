package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.bond_nodes'

assert(type(mod) == 'table', 'bond_nodes object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')
assert(type(mod.root_ids) == 'table', 'mod.root_ids should be a table')
assert(type(mod.by_line) == 'table', 'mod.by_line should be a table')
assert(type(mod.by_group) == 'table', 'mod.by_group should be a table')

assert(#mod.list == 100, 'expected 100 bond nodes')
assert(#mod.root_ids == 6, 'expected 6 root bond nodes')

assert(mod.by_id['bond_body_core'], 'expected bond_body_core to exist')
assert(mod.by_id['bond_body_core'].display_name == '体术', 'expected bond_body_core name to match')
assert(mod.by_id['bond_growth_bow_god_master'], 'expected bond_growth_bow_god_master to exist')
assert(mod.by_id['bond_growth_bow_god_master'].quality == 'epic', 'expected epic quality to be preserved')

print('[OK] bond nodes csv loader smoke passed')
