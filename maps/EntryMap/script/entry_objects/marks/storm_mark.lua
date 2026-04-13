return {
  id = 'storm_mark',
  name = '风暴进化',
  quality = 'rare',
  pool_weight = 7,
  tags = { 'basic_attack', 'spell_cycle' },
  summary = '攻击速度 +20%，所有攻击技能冷却缩减 10%；攻击技能释放后追加 1 次星火回响。',
  bonuses = {
    attr = {
      ['攻击速度'] = 20,
    },
    attack_skill = {
      cooldown_reduction = 0.10,
    },
  },
}
