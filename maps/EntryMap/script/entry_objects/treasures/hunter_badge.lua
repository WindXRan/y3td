return {
    id = 'hunter_badge',
    name = '猎手徽记',
    quality = 'common',
    summary = '普攻追加 15% 攻击的物理追击，物理攻击 +12。',
    pool_weight = 10,
    tags = { 'basic_attack', 'attack' },
    bonuses = {
      attr = {
        ['物理攻击'] = 12,
      },
      skill_runtime = {
        normal_attack_bonus_ratio = 0.15,
      },
    },
  }
