package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.attack_skill_second_batch_blueprints'

assert(type(mod) == 'table', 'second batch blueprints object table should return a table')
assert(mod.version == '2026-04-23', 'expected blueprint version to match')
assert(mod.status == 'basic_attack_only', 'expected blueprint status to match')
assert(type(mod.system) == 'table', 'expected blueprint system to be a table')
assert(type(mod.list) == 'table', 'expected blueprint list to be a table')
assert(type(mod.by_id) == 'table', 'expected blueprint by_id to be a table')

assert(#mod.list == 0, 'expected no active second batch skill')
assert(#mod.system.card_rule.growth_lanes == 9, 'expected 9 growth lanes')
assert(mod.system.slot_rule.fixed_base_slot == '普攻', 'expected fixed base slot to match')
assert(mod.system.slot_rule.free_attack_skill_slots == 0, 'expected no free attack skill slot in basic attack only mode')
assert(mod.system.slot_rule.total_attack_skills == 1, 'expected total attack skill count to only include basic attack')
assert(mod.system.card_rule.rarity_plan.legendary == 0, 'expected legendary rarity count to match')

assert(mod.by_id.sword_wave == nil, 'expected sword_wave blueprint to stay disabled in single-skill mode')
assert(mod.by_id.flying_swords == nil, 'expected flying_swords blueprint to stay disabled in basic attack only mode')

print('[OK] second batch blueprints csv loader smoke passed')
