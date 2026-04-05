return {
    id = 'field_bandage',
    name = '战地绷带',
    quality = 'common',
    summary = '最大生命 +260；每击杀 14 名主线敌人回复 75 生命。',
    pool_weight = 8,
    tags = { 'survival' },
    bonuses = {
      attr = {
        ['最大生命'] = 260,
      },
      skill_runtime = {
        medbot_every = 14,
        medbot_heal = 75,
      },
    },
  }
