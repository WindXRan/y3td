return {
  id = 'growth',
  name = '成长',
  quality = 'rare',
  required_count = 4,
  pool_weight = 6,
  tier = 't1',
  bond_role = 'material',
  result_type = 'evolve_keep',
  target_quality = 'rare',
  route_tags = { 'economy', 'basic_attack' },
  compose_inputs = {},
  compose_hint = '不屈反打路线的长期成长素材。',
  bond_effect_desc = '每击杀20个敌人永久攻击+12；每100击杀额外获得伤害加成+4%。',
  runtime = {
    growth_active = 1,
  },
}
