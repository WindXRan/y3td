return {
    id = 'execute',
    name = '处决',
    quality = 'rare',
    required_count = 3,
    pool_weight = 8,
    bond_effect_desc = '对生命低于35%的敌人造成的伤害额外+40%。',
    runtime = {
      execute_damage_bonus = 0.40,
      execute_threshold = 0.35,
    },
  }
