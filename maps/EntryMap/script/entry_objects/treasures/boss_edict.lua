return {
  id = 'boss_edict',
  name = '统御敕令',
  quality = 'epic',
  summary = '下一个 Boss 战开始后 60 秒内攻击速度 +25%，Boss 伤害 +35%。',
  pool_weight = 4,
  tags = { 'boss', 'timed' },
  treasure_type = 'tactical_temp',
  duration_type = 'next_boss',
  theme_tags = { 'boss', 'tempo' },
  best_with_tags = { 'boss', 'survival' },
  timing_tags = { 'next_boss' },
  duration = {
    trigger = 'next_boss',
    active_duration_sec = 60,
  },
  bonuses = {
    attr = {
      ['攻击速度'] = 25,
    },
    runtime = {
      boss_damage_bonus = 0.35,
    },
  },
}
