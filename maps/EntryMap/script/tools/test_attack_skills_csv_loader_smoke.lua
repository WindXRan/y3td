package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.attack_skills'

assert(type(mod) == 'table', 'attack_skills object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.defs_by_id) == 'table', 'mod.defs_by_id should be a table')
assert(type(mod.vfx_by_id) == 'table', 'mod.vfx_by_id should be a table')
assert(type(mod.blueprints) == 'table', 'mod.blueprints should be a table')
assert(type(mod.blueprint_by_id) == 'table', 'mod.blueprint_by_id should be a table')

assert(#mod.list == 1, 'expected only basic_attack to remain in attack_skills.csv')

local basic_attack = mod.defs_by_id.basic_attack
assert(basic_attack, 'expected basic_attack to exist')
assert(basic_attack.default_slot == 1, 'expected basic_attack default_slot to match')
assert(basic_attack.base_range == 820, 'expected basic_attack base_range to match')
assert(basic_attack.base_cooldown == 1.05, 'expected basic_attack base_cooldown to match')
assert(basic_attack.damage_label == '金行飞剑', 'expected basic_attack damage label to match')
assert(mod.vfx_by_id.basic_attack.projectile_key == 134267104, 'expected basic_attack projectile_key to match')
assert(mod.vfx_by_id.basic_attack.cast_particle == nil, 'expected basic_attack cast_particle to be empty')
assert(mod.vfx_by_id.basic_attack.impact_particle == nil, 'expected basic_attack impact_particle to be empty')
assert(mod.vfx_by_id.basic_attack.chain_particle == nil, 'expected basic_attack chain_particle to be empty')

assert(mod.blueprint_by_id.sword_wave ~= nil, 'expected blueprint bridge to remain intact')
assert(mod.defs_by_id.sword_wave ~= nil, 'expected sword_wave def to be bridged into defs_by_id')
assert(mod.defs_by_id.sword_wave.base_range == 980, 'expected sword_wave base_range to match')
assert(mod.defs_by_id.sword_wave.ui_icon == 106990, 'expected sword_wave icon to be bridged into defs_by_id')
assert(mod.defs_by_id.sword_wave.evolution_name == '崩岳天锋', 'expected sword_wave evolution name to match')
assert(mod.vfx_by_id.sword_wave.projectile_key == 201364743, 'expected sword_wave projectile_key to use its dedicated projectile')
assert(mod.vfx_by_id.arcane_ray.projectile_key == 134264830, 'expected arcane_ray projectile_key to use its dedicated projectile')
assert(mod.vfx_by_id.moon_blade.projectile_key == 201364750, 'expected moon_blade projectile_key to use its dedicated projectile')
assert(mod.vfx_by_id.fireball.projectile_key == 201364749, 'expected fireball projectile_key to use its dedicated projectile')
assert(mod.vfx_by_id.flying_swords.projectile_key == 201364753, 'expected flying_swords projectile_key to use its dedicated projectile')

print('[OK] attack skills csv loader smoke passed')
