local M = {
    id = 'thunder',
    name = '天雷',
    summary = '召唤 1 道天雷打击目标，造成电系魔法伤害。',
    damage_type = '法术',
    base_damage_ratio = 2.0,
    base_cooldown = 5.5,
    base_range = 950,
    base_extra_targets = 0,
  }

M.vfx = {
    charge_particle = 102740,
    charge_scale = 0.85,
    charge_time = 0.16,
    impact_particle = 102731,
    impact_scale = 1.20,
    impact_time = 0.40,
    chain_particle = 102740,
    chain_scale = 0.85,
    chain_time = 0.25,
    strike_delay = 0.12,
  }

return M
