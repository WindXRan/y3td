package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.attack_skill_second_batch_blueprints'

assert(type(mod) == 'table', 'second batch blueprints object table should return a table')
assert(mod.version == '2026-04-12', 'expected blueprint version to match')
assert(mod.status == 'design_in_repo', 'expected blueprint status to match')
assert(type(mod.system) == 'table', 'expected blueprint system to be a table')
assert(type(mod.list) == 'table', 'expected blueprint list to be a table')
assert(type(mod.by_id) == 'table', 'expected blueprint by_id to be a table')

assert(#mod.list == 11, 'expected 11 second batch skills')
assert(#mod.system.card_rule.growth_lanes == 9, 'expected 9 growth lanes')
assert(mod.system.slot_rule.fixed_base_slot == '普攻', 'expected fixed base slot to match')
assert(mod.system.card_rule.rarity_plan.legendary == 1, 'expected legendary rarity count to match')

local sword_wave = mod.by_id.sword_wave
assert(sword_wave, 'expected sword_wave blueprint to exist')
assert(sword_wave.base.pierce == 2, 'expected sword_wave pierce to match')
assert(sword_wave.evolution.id == 'mountain_breaker_wave', 'expected sword_wave evolution id to match')
assert(#sword_wave.cards.common == 3, 'expected sword_wave common cards count to match')
assert(sword_wave.cards.rare[2].id == 'sword_wave_elite', 'expected sword_wave rare card order to match')

local chain_lightning = mod.by_id.chain_lightning
assert(chain_lightning, 'expected chain_lightning blueprint to exist')
assert(chain_lightning.base.bounce == 5, 'expected chain_lightning bounce to match')
assert(chain_lightning.cards.legendary[1].name == '永续雷链', 'expected chain_lightning legendary card to match')

local fireball = mod.by_id.fireball
assert(fireball, 'expected fireball blueprint to exist')
assert(fireball.base.radius == 200, 'expected fireball radius to match')
assert(fireball.cards.excellent[3].lane == 'form', 'expected fireball excellent form card to match')

print('[OK] second batch blueprints csv loader smoke passed')
