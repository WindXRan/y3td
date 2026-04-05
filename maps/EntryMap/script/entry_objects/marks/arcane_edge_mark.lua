return {
  id = 'arcane_edge_mark',
  name = '奥锋烙印',
  quality = 'rare',
  pool_weight = 7,
  tags = { 'attack_spell', 'burst' },
  summary = '所有攻击技能伤害 +20%，攻击技能射程 +60。',
  bonuses = {
    runtime = {
      skill_damage_bonus = 0.20,
    },
    attack_skill = {
      range_bonus = 60,
    },
  },
}
