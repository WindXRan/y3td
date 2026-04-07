return {
    id = 'feather_quiver',
    name = '翎羽箭囊',
    quality = 'common',
    summary = '普攻溅射 30% 攻击，溅射半径 +120。',
    pool_weight = 9,
    tags = { 'basic_attack', 'aoe' },
    treasure_type = 'route_amp',
    duration_type = 'permanent',
    theme_tags = { 'basic_attack', 'aoe' },
    best_with_tags = { 'basic_attack', 'barrage', 'clear' },
    timing_tags = { 'immediate', 'persistent' },
    bonuses = {
      skill_runtime = {
        splash_ratio = 0.30,
        splash_radius = 120,
      },
    },
  }
