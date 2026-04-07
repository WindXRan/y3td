return {
  id = 'charged_talisman',
  name = '蓄雷符',
  quality = 'rare',
  summary = '45 秒内非普攻攻击技能伤害 +25%，天雷额外连锁 1 个目标。',
  pool_weight = 6,
  tags = { 'skill', 'timed' },
  treasure_type = 'tactical_temp',
  duration_type = 'timed',
  theme_tags = { 'skill' },
  best_with_tags = { 'skill', 'timed' },
  timing_tags = { 'timed' },
  duration = {
    trigger = 'immediate',
    duration_sec = 45,
  },
  bonuses = {
    runtime = {
      skill_damage_bonus = 0.25,
    },
    skill_runtime = {
      extra_targets = 1,
    },
  },
}
