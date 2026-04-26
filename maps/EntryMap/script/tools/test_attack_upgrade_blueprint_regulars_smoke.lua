package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local AttackSkillBlueprints = require 'data.object_tables.attack_skill_second_batch_blueprints'

assert(type(AttackSkillBlueprints) == 'table', 'expected blueprints object table to be a table')
assert(type(AttackSkillBlueprints.list) == 'table', 'expected blueprints list to be a table')
assert(#AttackSkillBlueprints.list == 2, 'expected two active sample attack skill blueprints')
assert(AttackSkillBlueprints.by_id.chain_lightning ~= nil, 'expected chain_lightning blueprint to be active')
assert(AttackSkillBlueprints.by_id.fireball ~= nil, 'expected fireball blueprint to be active')
assert(AttackSkillBlueprints.by_id.flying_swords == nil, 'expected inactive blueprints to stay disabled')

print('[OK] attack upgrade blueprint regulars smoke passed')
