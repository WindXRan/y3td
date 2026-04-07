return {
  id = 'emergency_ration',
  name = '紧急口粮',
  quality = 'rare',
  summary = '接下来 3 次受伤后，立即回复 5% 最大生命并获得 12% 伤害减免，持续 2 秒。',
  pool_weight = 6,
  tags = { 'survival', 'charges' },
  treasure_type = 'tactical_temp',
  duration_type = 'charges',
  theme_tags = { 'survival', 'timed' },
  best_with_tags = { 'survival', 'burst' },
  timing_tags = { 'charges' },
  duration = {
    trigger = 'immediate',
    max_charges = 3,
    guard_duration = 2,
  },
  bonuses = {
    on_hit = {
      heal_ratio = 0.05,
      damage_reduction = 12,
    },
  },
}
