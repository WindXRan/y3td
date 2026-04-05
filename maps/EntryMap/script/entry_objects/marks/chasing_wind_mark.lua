return {
  id = 'chasing_wind_mark',
  name = '追风烙印',
  quality = 'common',
  pool_weight = 10,
  tags = { 'basic_attack' },
  summary = '普攻节奏提升，普攻伤害 +15%。',
  bonuses = {
    attr = {
      ['攻击速度'] = 14,
    },
    runtime = {
      normal_attack_damage_bonus = 0.15,
    },
  },
}
