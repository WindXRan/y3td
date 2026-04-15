local M = {
    id = 'basic_attack',
    name = '普攻',
    default_slot = 1,
    summary = '凝出 1 道金行剑罡，造成 100% 攻击的金行箭罡伤害。',
    damage_type = '物理',
    damage_form = 'weapon',
    element = 'metal',
    damage_label = '金行箭罡',
    base_damage_ratio = 1.0,
    base_cooldown = 1.6,
    base_range = 760,
  }

M.vfx = {
    projectile_key = 134222874,
    projectile_speed = 1320,
    projectile_time = 1.8,
    target_distance = 48,
    cast_particle = 102820,
    cast_scale = 0.50,
    cast_time = 0.10,
    impact_particle = 102820,
    impact_scale = 0.75,
    impact_time = 0.22,
  }

return M
