local M = {
    id = 'basic_attack',
    name = '普攻',
    default_slot = 1,
    summary = '射出 1 支破空箭矢直取敌人，造成 125% 攻击的金行箭矢伤害。',
    damage_type = '物理',
    damage_form = 'weapon',
    element = 'metal',
    damage_label = '金行箭矢',
    base_damage_ratio = 1.25,
    base_cooldown = 1.05,
    base_range = 820,
    base_explosion_ratio = 0,
    base_explosion_radius = 0,
  }

M.vfx = {
    projectile_key = 134267104,
    projectile_speed = 1880,
    projectile_time = 1.45,
    target_distance = 28,
  }

return M
