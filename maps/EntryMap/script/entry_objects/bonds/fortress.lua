return {
  id = 'fortress',
  name = '坚壁',
  quality = 'rare',
  required_count = 4,
  pool_weight = 6,
  tier = 't1',
  bond_role = 'material',
  result_type = 'evolve_keep',
  target_quality = 'rare',
  route_tags = { 'survival', 'boss' },
  compose_inputs = {},
  compose_hint = '不屈反打路线的站场减伤素材。',
  bond_effect_desc = '生命高于80%时伤害减免+12；生命低于50%时每秒回复3%最大生命。',
  runtime = {
    fortress_active = 1,
  },
}
