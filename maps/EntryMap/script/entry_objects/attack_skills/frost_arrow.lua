local M = {
    id = 'frost_arrow',
    name = '寒冰箭',
    summary = '射出 1 支寒冰箭，造成冰系魔法伤害并短暂击退目标。',
    damage_type = '法术',
    base_damage_ratio = 1.7,
    base_cooldown = 4.8,
    base_range = 920,
    base_pierce = 0,
    base_pierce_width = 95,
    base_control_lock_time = 0.20,
    base_knockback_distance = 90,
    base_knockback_speed = 880,
  }

M.vfx = {
    projectile_key = 134236870,
    projectile_speed = 920,
    projectile_time = 3.0,
    target_distance = 70,
    cast_particle = 102750,
    cast_scale = 0.80,
    cast_time = 0.20,
    impact_particle = 102754,
    impact_scale = 1.00,
    impact_time = 0.35,
  }

return M
