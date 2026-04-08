return {
  id = 'greed',
  name = '贪欲',
  quality = 'common',
  required_count = 2,
  pool_weight = 9,
  tier = 't1',
  bond_role = 'standalone',
  result_type = 'terminal_swallow',
  target_quality = 'common',
  route_tags = { 'economy', 'all_builds' },
  compose_inputs = {},
  compose_hint = '资源挂件，不进入主进化链。',
  bond_effect_desc = '每击杀30个敌人，额外获得40木材与30金币。',
  runtime = {
    greed_active = 1,
  },
}
