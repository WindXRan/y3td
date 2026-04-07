return {
  id = 'resonance',
  name = '共鸣',
  quality = 'rare',
  required_count = 2,
  pool_weight = 7,
  tier = 't1',
  bond_role = 'material',
  result_type = 'evolve_keep',
  target_quality = 'rare',
  route_tags = { 'element', 'skill' },
  compose_inputs = {},
  compose_hint = '加强技能伤害与奥术延伸。',
  bond_effect_desc = '非普攻攻击技能伤害 +18%，奥术箭次级目标 +1。',
  runtime = {
    skill_damage_bonus = 0.18,
    secondary_targets = 1,
  },
}
