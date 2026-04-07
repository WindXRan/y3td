return {
    id = 'thunder_pin',
    name = '雷鸣徽针',
    quality = 'rare',
    summary = '普攻 35% 概率弹射 1 个目标，造成 65% 法术伤害。',
    pool_weight = 7,
    tags = { 'basic_attack', 'bounce' },
    treasure_type = 'route_amp',
    duration_type = 'permanent',
    theme_tags = { 'basic_attack', 'bounce' },
    best_with_tags = { 'chain', 'basic_attack', 'clear' },
    timing_tags = { 'immediate', 'persistent' },
    bonuses = {
      skill_runtime = {
        chain_chance = 0.35,
        chain_bounces = 1,
        chain_ratio = 0.65,
      },
    },
  }
