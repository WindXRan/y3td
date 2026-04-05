return {
  id = 'hunter_king_mark',
  name = '猎王烙印',
  quality = 'common',
  pool_weight = 10,
  tags = { 'boss', 'boss_damage' },
  summary = '对精英与 Boss 伤害 +15%。',
  bonuses = {
    runtime = {
      boss_damage_bonus = 0.15,
      elite_damage_bonus = 0.15,
    },
  },
}
