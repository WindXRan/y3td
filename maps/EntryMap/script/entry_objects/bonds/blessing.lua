return {
  id = 'blessing',
  name = '祝福',
  quality = 'rare',
  required_count = 2,
  pool_weight = 10,
  tier = 't1',
  bond_role = 'child',
  result_type = 'evolve_keep',
  target_quality = 'rare',
  route_tags = { 'survival', 'basic_attack' },
  compose_inputs = {},
  compose_hint = '不屈反打路线的回复主件。',
  bond_effect_desc = '每8秒回复6%最大生命，并获得8%伤害减免，持续2秒。',
  runtime = {
    blessing_active = 1,
  },
}
