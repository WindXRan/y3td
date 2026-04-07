return {
  id = 'challenge_banner',
  name = '挑战战旗',
  quality = 'epic',
  summary = '下一次挑战中对精英与 Boss 伤害 +40%，挑战完成后额外获得 1 次宝物免费刷新。',
  pool_weight = 4,
  tags = { 'challenge', 'boss' },
  treasure_type = 'tactical_temp',
  duration_type = 'next_challenge',
  theme_tags = { 'boss', 'challenge' },
  best_with_tags = { 'boss', 'survival' },
  timing_tags = { 'next_challenge' },
  duration = {
    trigger = 'next_challenge',
    bonus_refreshes = 1,
  },
  bonuses = {
    runtime = {
      boss_damage_bonus = 0.40,
      elite_damage_bonus = 0.40,
      challenge_damage_bonus = 0.40,
    },
  },
}
