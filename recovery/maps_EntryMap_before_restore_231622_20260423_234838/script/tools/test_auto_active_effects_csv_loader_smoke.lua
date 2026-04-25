package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.auto_active_effects'

assert(type(mod) == 'table', 'auto_active_effects object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')

assert(#mod.list == 8, 'expected 8 auto active effects after removing legacy treasure-only effects')

local spell_burst = mod.by_id.spell_burst
assert(spell_burst, 'expected spell_burst to exist')
assert(spell_burst.source_type == 'bond', 'expected spell_burst source_type to match')
assert(spell_burst.cooldown == 18.0, 'expected spell_burst cooldown to match')
assert(spell_burst.range == 900, 'expected spell_burst range to match')
assert(spell_burst.radius == 300, 'expected spell_burst radius to match')

local fighting_spirit = mod.by_id.fighting_spirit_field
assert(fighting_spirit, 'expected fighting_spirit_field to exist')
assert(fighting_spirit.modifier_key == 201365014, 'expected fighting_spirit_field modifier_key to match')
assert(fighting_spirit.extra_hp_ratio == 0.30, 'expected fighting_spirit_field extra_hp_ratio to match')
assert(fighting_spirit.attack_reduction_ratio == 0.30, 'expected fighting_spirit_field attack_reduction_ratio to match')

local charge_breaker = mod.by_id.charge_breaker_rally
assert(charge_breaker, 'expected charge_breaker_rally to exist')
assert(charge_breaker.counter_required == 200, 'expected charge_breaker_rally counter_required to match')
assert(charge_breaker.duration == 10.0, 'expected charge_breaker_rally duration to match')
assert(charge_breaker.attr['力量'] == 20, 'expected charge_breaker_rally 力量 attr to match')
assert(charge_breaker.attr['攻击速度'] == 50, 'expected charge_breaker_rally 攻击速度 attr to match')
assert(charge_breaker.attr['技能急速'] == 30, 'expected charge_breaker_rally 技能急速 attr to match')

assert(mod.by_id.guardian_pulse == nil, 'legacy guardian_pulse treasure effect should be removed')
assert(mod.by_id.harvest_blade == nil, 'legacy harvest_blade treasure effect should be removed')
assert(mod.by_id.coin_burst == nil, 'legacy coin_burst treasure effect should be removed')

print('[OK] auto active effects csv loader smoke passed')
