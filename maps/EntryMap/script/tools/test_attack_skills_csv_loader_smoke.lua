package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.attack_skills'

assert(type(mod) == 'table', 'attack_skills object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.defs_by_id) == 'table', 'mod.defs_by_id should be a table')
assert(type(mod.vfx_by_id) == 'table', 'mod.vfx_by_id should be a table')
assert(type(mod.blueprints) == 'table', 'mod.blueprints should be a table')
assert(type(mod.blueprint_by_id) == 'table', 'mod.blueprint_by_id should be a table')

assert(#mod.list == 1, 'expected only basic_attack to remain in attack_skills.csv')
assert(#mod.blueprints.list == 2, 'expected two active second batch sample blueprints')

local basic_attack = mod.defs_by_id.basic_attack
assert(basic_attack, 'expected basic_attack to exist')
assert(basic_attack.default_slot == 1, 'expected basic_attack default_slot to match')
assert(basic_attack.base_range == 820, 'expected basic_attack base_range to match')
assert(basic_attack.base_cooldown == 1.05, 'expected basic_attack base_cooldown to match')
assert(basic_attack.damage_label == '金行箭矢', 'expected basic_attack damage label to match')
assert(mod.vfx_by_id.basic_attack.projectile_key == 134267104, 'expected basic_attack projectile_key to match')
assert(mod.vfx_by_id.basic_attack.cast_particle == 101175, 'expected basic_attack cast_particle to match editor manifest')
assert(mod.vfx_by_id.basic_attack.impact_particle == 101175, 'expected basic_attack impact_particle to match editor manifest')
assert(mod.vfx_by_id.basic_attack.chain_particle == 101175, 'expected basic_attack chain_particle to match editor manifest')

assert(mod.blueprint_by_id.chain_lightning ~= nil, 'expected chain_lightning blueprint bridge to be active')
assert(mod.blueprint_by_id.fireball ~= nil, 'expected fireball blueprint bridge to be active')
assert(mod.defs_by_id.chain_lightning ~= nil, 'expected chain_lightning def to be active')
assert(mod.defs_by_id.fireball ~= nil, 'expected fireball def to be active')
assert(mod.defs_by_id.flying_swords == nil, 'expected flying_swords def to stay out of defs_by_id')
assert(mod.vfx_by_id.basic_attack and mod.vfx_by_id.basic_attack.projectile_key == 134267104,
  'expected basic_attack projectile_key to match')
assert(mod.defs_by_id.basic_attack and mod.defs_by_id.basic_attack.editor_projectile_key == 134267104,
  'expected basic_attack editor_projectile_key to expose projectile key')
assert(mod.defs_by_id.chain_lightning.editor_ability_key == 201390006,
  'expected chain_lightning editor ability key to match')
assert(mod.defs_by_id.fireball.editor_ability_key == 201390012,
  'expected fireball editor ability key to match')
assert(mod.vfx_by_id.chain_lightning.projectile_key == 134278613,
  'expected chain_lightning projectile key to match')
assert(mod.vfx_by_id.fireball.projectile_key == 201364749,
  'expected fireball projectile key to match')

print('[OK] attack skills csv loader smoke passed')
