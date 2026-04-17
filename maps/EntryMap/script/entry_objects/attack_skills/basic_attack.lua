local M = {
    id = 'basic_attack',
    name = '普攻',
    default_slot = 1,
    summary = '凝出 1 道御剑剑罡，造成 110% 攻击的金行剑罡伤害。',
    damage_type = '物理',
    damage_form = 'weapon',
    element = 'metal',
    damage_label = '金行剑罡',
    base_damage_ratio = 1.1,
    base_cooldown = 1.25,
    base_range = 760,
  }

M.vfx = {
    projectile_key = 134222874,
    projectile_speed = 1680,
    projectile_time = 1.35,
    target_distance = 34,
    cast_particle = 102740,
    cast_scale = 0.42,
    cast_time = 0.10,
    impact_particle = 102731,
    impact_scale = 0.90,
    impact_time = 0.24,
    chain_particle = 102877,
    chain_scale = 0.68,
    chain_time = 0.18,
  }

return M
