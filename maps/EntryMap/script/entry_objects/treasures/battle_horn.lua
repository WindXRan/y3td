return {
  id = 'battle_horn',
  name = '战吼号角',
  quality = 'rare',
  summary = '本波内攻击速度 +35，普攻伤害 +18%。',
  pool_weight = 8,
  tags = { 'basic_attack', 'wave_clear' },
  treasure_type = 'tactical_temp',
  duration_type = 'wave',
  theme_tags = { 'tempo', 'basic_attack' },
  best_with_tags = { 'basic_attack', 'barrage', 'wave_clear' },
  timing_tags = { 'wave' },
  duration = {
    trigger = 'immediate',
    expire_on_wave_change = true,
  },
  bonuses = {
    attr = {
      ['攻击速度'] = 35,
    },
    runtime = {
      normal_attack_damage_bonus = 0.18,
    },
  },
}
