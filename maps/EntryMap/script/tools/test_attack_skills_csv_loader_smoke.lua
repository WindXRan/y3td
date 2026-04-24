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
assert(basic_attack.damage_label == '金行箭矢', 'expected basic_attack damage label to match')
assert(mod.vfx_by_id.basic_attack.projectile_key == 134267104, 'expected basic_attack projectile_key to match')
assert(mod.vfx_by_id.basic_attack.cast_particle == nil, 'expected basic_attack cast_particle to be empty')
assert(mod.vfx_by_id.basic_attack.impact_particle == nil, 'expected basic_attack impact_particle to be empty')
assert(mod.vfx_by_id.basic_attack.chain_particle == nil, 'expected basic_attack chain_particle to be empty')

assert(next(mod.blueprint_by_id) == nil, 'expected blueprint bridge to be empty in basic attack only mode')
assert(mod.defs_by_id.flying_swords == nil, 'expected flying_swords def to stay out of defs_by_id')
assert(mod.vfx_by_id.basic_attack and mod.vfx_by_id.basic_attack.projectile_key == 134267104,
  'expected basic_attack projectile_key to match')
assert(mod.defs_by_id.basic_attack and mod.defs_by_id.basic_attack.editor_projectile_key == 134267104,
  'expected basic_attack editor_projectile_key to expose projectile key')

print('[OK] attack skills csv loader smoke passed')
