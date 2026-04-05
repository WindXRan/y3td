return {
  id = 'slayer_mark',
  name = '弑王烙印',
  quality = 'rare',
  pool_weight = 7,
  tags = { 'boss', 'elite' },
  summary = '对精英与 Boss 伤害 +24%，并获得伤害加成 +6%。',
  bonuses = {
    attr = {
      ['伤害加成'] = 6,
    },
    runtime = {
      boss_damage_bonus = 0.24,
      elite_damage_bonus = 0.24,
    },
  },
}
