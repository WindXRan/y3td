package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.attack_skill_second_batch_blueprints'

assert(type(mod) == 'table', 'second batch blueprints object table should return a table')
assert(mod.version == '2026-04-17', 'expected blueprint version to match')
assert(mod.status == 'runtime_in_repo', 'expected blueprint status to match')
assert(type(mod.system) == 'table', 'expected blueprint system to be a table')
assert(type(mod.list) == 'table', 'expected blueprint list to be a table')
assert(type(mod.by_id) == 'table', 'expected blueprint by_id to be a table')

assert(#mod.list == 1, 'expected only one active second batch skill')
assert(#mod.system.card_rule.growth_lanes == 9, 'expected 9 growth lanes')
assert(mod.system.slot_rule.fixed_base_slot == '普攻', 'expected fixed base slot to match')
assert(mod.system.slot_rule.free_attack_skill_slots == 1, 'expected one free attack skill slot while single-skill mode is active')
assert(mod.system.slot_rule.total_attack_skills == 2, 'expected total attack skill count to include basic attack plus one active skill')
assert(mod.system.card_rule.rarity_plan.legendary == 1, 'expected legendary rarity count to match')

assert(mod.by_id.sword_wave == nil, 'expected sword_wave blueprint to stay disabled in single-skill mode')

local flying_swords = mod.by_id.flying_swords
assert(flying_swords, 'expected flying_swords blueprint to exist')
assert(flying_swords.name == '诛邪飞剑', 'expected flying_swords name to match')
assert(flying_swords.summary ~= nil and flying_swords.summary ~= '', 'expected flying_swords summary to exist')
assert(flying_swords.ui_icon == 106944, 'expected flying_swords icon to match')
assert(flying_swords.base.range == 930, 'expected flying_swords range to match')
assert(flying_swords.base.bounce == 4, 'expected flying_swords bounce to match')
assert(flying_swords.evolution.id == 'flying_swords_legend', 'expected flying_swords evolution id to match')
assert(#flying_swords.cards.common == 3, 'expected flying_swords common cards count to match')
assert(flying_swords.cards.excellent[2].name == '双匣齐开', 'expected flying_swords excellent card order to match')
assert(flying_swords.cards.legendary[1].name == '万剑归宗', 'expected flying_swords legendary card to match')

print('[OK] second batch blueprints csv loader smoke passed')
