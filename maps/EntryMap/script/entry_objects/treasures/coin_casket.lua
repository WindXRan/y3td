return {
    id = 'coin_casket',
    name = '铜币匣',
    quality = 'common',
    summary = '金币奖励 +25%，每秒额外获得 1 金币。',
    pool_weight = 8,
    tags = { 'economy' },
    bonuses = {
      reward_ratio = {
        gold = 0.25,
      },
      passive_income = {
        gold = 1,
      },
    },
  }
