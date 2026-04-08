return {
  id = 'berserk',
  name = '狂战',
  quality = 'rare',
  required_count = 2,
  pool_weight = 10,
  tier = 't1',
  bond_role = 'child',
  result_type = 'evolve_keep',
  target_quality = 'rare',
  route_tags = { 'low_hp', 'basic_attack' },
  compose_inputs = {},
  compose_hint = '不屈反打路线的低血主件。',
  bond_effect_desc = '生命低于50%时，额外获得攻速+35%与普攻伤害+25%。',
  runtime = {
    berserk_active = 1,
  },
}
