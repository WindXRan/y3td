package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local AttackSkillBlueprints = require 'data.object_tables.attack_skill_second_batch_blueprints'

assert(type(AttackSkillBlueprints) == 'table', 'expected blueprints object table to be a table')
assert(type(AttackSkillBlueprints.list) == 'table', 'expected blueprints list to be a table')
assert(#AttackSkillBlueprints.list == 0, 'expected attack skill blueprints to be disabled in basic attack only mode')
assert(next(AttackSkillBlueprints.by_id) == nil, 'expected attack skill blueprint map to be empty')

print('[OK] attack upgrade blueprint regulars smoke passed')
