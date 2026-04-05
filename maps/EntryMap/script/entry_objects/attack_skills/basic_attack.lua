local M = {
    id = 'basic_attack',
    name = '普攻',
    default_slot = 1,
    summary = '发射 1 支箭矢，造成 100% 攻击的物理伤害。',
    damage_type = '物理',
    base_damage_ratio = 1.0,
    base_cooldown = 1.6,
    base_range = 760,
  }

M.vfx = {
    projectile_key = 134257292,
    projectile_speed = 1100,
    projectile_time = 2.2,
    target_distance = 55,
    impact_particle = 102820,
    impact_scale = 0.60,
    impact_time = 0.18,
  }

return M
