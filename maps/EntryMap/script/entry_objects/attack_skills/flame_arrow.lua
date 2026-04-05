local M = {
    id = 'flame_arrow',
    name = '爆炎箭',
    summary = '射出 1 支爆炎箭，命中后爆炸造成火系物理伤害。',
    damage_type = '物理',
    base_damage_ratio = 2.2,
    base_cooldown = 6.2,
    base_range = 900,
    base_explosion_ratio = 1.8,
    base_explosion_radius = 220,
  }

M.vfx = {
    projectile_key = 134218466,
    projectile_speed = 980,
    projectile_time = 3.0,
    target_distance = 75,
    cast_particle = 102521,
    cast_scale = 0.85,
    cast_time = 0.20,
    impact_particle = 102702,
    impact_scale = 1.10,
    impact_time = 0.35,
    explosion_particle = 102705,
    explosion_scale = 1.20,
    explosion_time = 0.45,
  }

return M
