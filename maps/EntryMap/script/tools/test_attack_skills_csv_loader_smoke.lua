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
assert(mod.vfx_by_id.basic_attack.projectile_speed == 3760, 'expected basic_attack projectile_speed to match')
assert(mod.vfx_by_id.basic_attack.projectile_time == 2.9, 'expected basic_attack projectile_time to match')
assert(mod.vfx_by_id.basic_attack.target_distance == 28, 'expected basic_attack target_distance to match')
assert(mod.vfx_by_id.basic_attack.cast_particle == 101175, 'expected basic_attack cast_particle to match')
assert(mod.vfx_by_id.basic_attack.impact_particle == 101175, 'expected basic_attack impact_particle to match')
assert(mod.vfx_by_id.basic_attack.chain_particle == 101175, 'expected basic_attack chain_particle to match')

assert(mod.blueprint_by_id.flying_swords ~= nil, 'expected flying_swords blueprint bridge to remain intact')
assert(mod.blueprint_by_id.sword_wave == nil, 'expected disabled blueprints to stay out of blueprint_by_id')
assert(mod.defs_by_id.flying_swords ~= nil, 'expected flying_swords def to be bridged into defs_by_id')
assert(mod.defs_by_id.sword_wave == nil, 'expected disabled blueprint defs to stay out of defs_by_id')
assert(mod.defs_by_id.flying_swords.base_range == 930, 'expected flying_swords base_range to match')
assert(mod.defs_by_id.flying_swords.ui_icon == 106944, 'expected flying_swords icon to be bridged into defs_by_id')
assert(mod.defs_by_id.flying_swords.evolution_name == '万剑归宗', 'expected flying_swords evolution name to match')

local expected_projectiles = {
  basic_attack = 134267104,
  flying_swords = 201364753,
}

for skill_id, projectile_key in pairs(expected_projectiles) do
  assert(mod.vfx_by_id[skill_id] and mod.vfx_by_id[skill_id].projectile_key == projectile_key,
    string.format('expected %s projectile_key to use projectile %s', skill_id, tostring(projectile_key)))
  assert(mod.defs_by_id[skill_id] and mod.defs_by_id[skill_id].editor_projectile_key == projectile_key,
    string.format('expected %s editor_projectile_key to expose projectile %s', skill_id, tostring(projectile_key)))
end

assert(mod.vfx_by_id.sword_wave == nil, 'expected disabled blueprint vfx to stay out of active vfx map')

print('[OK] attack skills csv loader smoke passed')
