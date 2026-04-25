package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.bond_misc_config'

assert(type(mod) == 'table', 'bond misc config should be a table')
assert(mod.group_labels.archery == '箭术', 'expected archery group label')
assert(mod.per_second_attr_keys.attack_per_second == '攻击', 'expected attack_per_second attr key')
assert(type(mod.manual_color_keywords.green) == 'table', 'expected green manual color keywords')
assert(type(mod.manual_color_keywords.cyan) == 'table', 'expected cyan manual color keywords')
assert(mod.manual_color_keywords.green[1] == '自适应伤害', 'expected first green keyword')
assert(mod.manual_color_keywords.cyan[1] == '%d+%.?%d*%%', 'expected first cyan pattern')

print('[OK] bond misc config csv loader smoke passed')
