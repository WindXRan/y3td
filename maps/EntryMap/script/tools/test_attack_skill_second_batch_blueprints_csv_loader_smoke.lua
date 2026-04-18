package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.attack_skill_second_batch_blueprints'

assert(type(mod) == 'table', 'second batch blueprints object table should return a table')
assert(mod.version == '2026-04-17', 'expected blueprint version to match')
assert(mod.status == 'runtime_in_repo', 'expected blueprint status to match')
assert(type(mod.system) == 'table', 'expected blueprint system to be a table')
assert(type(mod.list) == 'table', 'expected blueprint list to be a table')
assert(type(mod.by_id) == 'table', 'expected blueprint by_id to be a table')

assert(#mod.list == 15, 'expected 15 second batch skills')
assert(#mod.system.card_rule.growth_lanes == 9, 'expected 9 growth lanes')
assert(mod.system.slot_rule.fixed_base_slot == '普攻', 'expected fixed base slot to match')
assert(mod.system.card_rule.rarity_plan.legendary == 1, 'expected legendary rarity count to match')

local sword_wave = mod.by_id.sword_wave
assert(sword_wave, 'expected sword_wave blueprint to exist')
assert(sword_wave.name == '金翎剑气', 'expected sword_wave name to match')
assert(sword_wave.summary ~= nil and sword_wave.summary ~= '', 'expected sword_wave summary to exist')
assert(sword_wave.ui_icon == 106990, 'expected sword_wave icon to match')
assert(sword_wave.base.range == 980, 'expected sword_wave range to match')
assert(sword_wave.base.pierce == 3, 'expected sword_wave pierce to match')
assert(sword_wave.evolution.id == 'mountain_breaker_wave', 'expected sword_wave evolution id to match')
assert(#sword_wave.cards.common == 3, 'expected sword_wave common cards count to match')
assert(sword_wave.cards.rare[2].name == '诛邪断岳', 'expected sword_wave rare card order to match')

local chain_lightning = mod.by_id.chain_lightning
assert(chain_lightning, 'expected chain_lightning blueprint to exist')
assert(chain_lightning.base.bounce == 6, 'expected chain_lightning bounce to match')
assert(chain_lightning.cards.legendary[1].name == '九霄雷劫', 'expected chain_lightning legendary card to match')

local fireball = mod.by_id.fireball
assert(fireball, 'expected fireball blueprint to exist')
assert(fireball.name == '三昧火珠', 'expected fireball name to match')
assert(fireball.ui_icon == 106977, 'expected fireball icon to match')
assert(fireball.base.radius == 220, 'expected fireball radius to match')
assert(fireball.cards.excellent[3].lane == 'form', 'expected fireball excellent form card to match')

local flying_swords = mod.by_id.flying_swords
assert(flying_swords, 'expected flying_swords blueprint to exist')
assert(flying_swords.cards.legendary[1].name == '万剑归宗', 'expected flying_swords legendary card to match')

print('[OK] second batch blueprints csv loader smoke passed')
