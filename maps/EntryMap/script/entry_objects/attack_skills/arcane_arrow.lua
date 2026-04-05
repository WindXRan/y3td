local M = {
    id = 'arcane_arrow',
    name = '奥术箭',
    summary = '射出 1 支奥术箭，造成能量魔法伤害。',
    damage_type = '法术',
    base_damage_ratio = 0.8,
    base_cooldown = 2.0,
    base_range = 900,
    base_pierce = 1,
  }

M.vfx = {
    projectile_key = 134222874,
    projectile_speed = 1200,
    projectile_time = 2.5,
    target_distance = 70,
    cast_particle = 102820,
    cast_scale = 0.75,
    cast_time = 0.20,
    impact_particle = 102820,
    impact_scale = 0.95,
    impact_time = 0.30,
  }

return M
