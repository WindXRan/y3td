return {
    id = 'harvest_flask',
    name = '丰收酒壶',
    quality = 'rare',
    summary = '木材奖励 +35%，经验奖励 +20%，击杀主线敌人额外 +1 金币。',
    pool_weight = 6,
    tags = { 'economy' },
    treasure_type = 'general',
    duration_type = 'permanent',
    theme_tags = { 'economy', 'growth' },
    best_with_tags = { 'greed', 'growth', 'economy' },
    timing_tags = { 'immediate', 'persistent' },
    bonuses = {
      reward_ratio = {
        wood = 0.35,
        exp = 0.20,
      },
      skill_runtime = {
        bonus_gold_on_kill = 1,
      },
    },
  }
