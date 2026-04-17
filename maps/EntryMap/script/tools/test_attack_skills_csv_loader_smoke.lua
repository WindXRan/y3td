package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.attack_skills'

assert(type(mod) == 'table', 'attack_skills object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.defs_by_id) == 'table', 'mod.defs_by_id should be a table')
assert(type(mod.vfx_by_id) == 'table', 'mod.vfx_by_id should be a table')
assert(type(mod.blueprints) == 'table', 'mod.blueprints should be a table')
assert(type(mod.blueprint_by_id) == 'table', 'mod.blueprint_by_id should be a table')

assert(#mod.list == 5, 'expected 5 attack skills')

local basic_attack = mod.defs_by_id.basic_attack
assert(basic_attack, 'expected basic_attack to exist')
assert(basic_attack.default_slot == 1, 'expected basic_attack default_slot to match')
assert(basic_attack.base_range == 760, 'expected basic_attack base_range to match')
assert(basic_attack.base_cooldown == 1.25, 'expected basic_attack base_cooldown to match')
assert(basic_attack.damage_label == '金行剑罡', 'expected basic_attack damage label to match')
assert(mod.vfx_by_id.basic_attack.projectile_key == 134222874, 'expected basic_attack projectile_key to match')
assert(mod.vfx_by_id.basic_attack.cast_particle == 102740, 'expected basic_attack cast_particle to match')
assert(mod.vfx_by_id.basic_attack.impact_particle == 102731, 'expected basic_attack impact_particle to match')
assert(mod.vfx_by_id.basic_attack.chain_particle == 102877, 'expected basic_attack chain_particle to match')
assert(mod.vfx_by_id.basic_attack.impact_particle ~= mod.vfx_by_id.arcane_arrow.impact_particle, 'basic attack should no longer share the same impact fx as arcane_arrow')

local flame_arrow = mod.defs_by_id.flame_arrow
assert(flame_arrow, 'expected flame_arrow to exist')
assert(flame_arrow.base_explosion_ratio == 1.8, 'expected flame_arrow explosion ratio to match')
assert(flame_arrow.base_explosion_radius == 220, 'expected flame_arrow explosion radius to match')
assert(mod.vfx_by_id.flame_arrow.explosion_particle == 102705, 'expected flame_arrow explosion_particle to match')

local frost_arrow = mod.defs_by_id.frost_arrow
assert(frost_arrow, 'expected frost_arrow to exist')
assert(frost_arrow.base_control_lock_time == 0.20, 'expected frost_arrow control_lock_time to match')
assert(frost_arrow.base_knockback_distance == 90, 'expected frost_arrow knockback distance to match')
assert(frost_arrow.base_knockback_speed == 880, 'expected frost_arrow knockback speed to match')

local thunder = mod.defs_by_id.thunder
assert(thunder, 'expected thunder to exist')
assert(thunder.base_extra_targets == 1, 'expected thunder extra_targets to match')
assert(mod.vfx_by_id.thunder.charge_particle == 102740, 'expected thunder charge_particle to match')
assert(mod.vfx_by_id.thunder.chain_particle == 102740, 'expected thunder chain_particle to match')
assert(mod.vfx_by_id.thunder.strike_delay == 0.12, 'expected thunder strike_delay to match')

assert(mod.blueprint_by_id.sword_wave ~= nil, 'expected blueprint bridge to remain intact')

print('[OK] attack skills csv loader smoke passed')
