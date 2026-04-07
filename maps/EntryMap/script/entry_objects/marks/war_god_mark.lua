return {
  id = 'war_god_mark',
  name = '战神烙印',
  quality = 'epic',
  pool_weight = 4,
  tags = { 'burst', 'boss', 'basic_attack' },
  summary = '伤害加成 +12%，普攻伤害 +20%，攻击技能伤害 +20%；每 8 次普攻触发 1 次血怒践踏。',
  bonuses = {
    attr = {
      ['伤害加成'] = 12,
    },
    runtime = {
      normal_attack_damage_bonus = 0.20,
      skill_damage_bonus = 0.20,
    },
  },
}
