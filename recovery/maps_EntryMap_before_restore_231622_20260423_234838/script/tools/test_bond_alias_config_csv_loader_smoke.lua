package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.bond_alias_config'

assert(type(mod) == 'table', 'bond alias config should be a table')
assert(mod.legacy_tags_by_node_id['bond_magic_core'][1] == 'arcane', 'expected arcane legacy route tag')
assert(mod.legacy_tags_by_node_id['bond_body_core'][1] == 'guardian', 'expected guardian reverse alias')
assert(mod.attr_aliases_from_runtime.critical_damage_bonus['物理暴伤'] == 100, 'expected critical damage attr alias')
assert(mod.runtime_aliases.spell_damage_bonus.skill_damage_bonus == 1, 'expected spell damage runtime alias')

print('[OK] bond alias config csv loader smoke passed')
