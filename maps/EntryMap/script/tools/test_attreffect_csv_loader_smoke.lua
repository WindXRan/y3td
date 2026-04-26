package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local attreffect = require 'data.object_tables.attreffect'

assert(type(attreffect) == 'table', 'attreffect loader should return a table')
assert(type(attreffect.list) == 'table', 'attreffect.list should be a table')
assert(type(attreffect.by_source) == 'table', 'attreffect.by_source should be a table')

local bond = attreffect.by_source.bond_node and attreffect.by_source.bond_node['bond_element_core']
assert(bond ~= nil, 'expected formal bond sample source to exist')
assert(bond.attr['魔法伤害'] == 5, 'expected formal bond sample magic bonus')
assert(bond.runtime['skill_damage_bonus'] == 0.05, 'expected formal bond sample runtime bonus')

local mark = attreffect.by_source.mark and attreffect.by_source.mark['storm_mark']
assert(mark ~= nil, 'expected mark sample source to exist')
assert(mark.attack_skill['cooldown_reduction'] == 0.10, 'expected attack_skill sample bonus')

local task = attreffect.by_source.mainline_task and attreffect.by_source.mainline_task['1-1']
assert(task ~= nil, 'expected mainline sample source to exist')
assert(task.attr['攻击范围'] == 100, 'expected mainline sample attr bonus')
assert(task.resource['wood'] == 50, 'expected mainline sample resource bonus')

local outgame = attreffect.by_source.outgame_bonus and attreffect.by_source.outgame_bonus['1-1:standard']
assert(outgame ~= nil, 'expected outgame sample source to exist')
assert(outgame.attr['攻击白字'] == 6, 'expected outgame sample attack bonus')

print('[OK] attreffect csv loader smoke passed')
