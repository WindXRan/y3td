return {
  id = 'burn',
  name = '灼烧',
  quality = 'rare',
  required_count = 2,
  pool_weight = 7,
  tier = 't1',
  bond_role = 'material',
  result_type = 'evolve_keep',
  target_quality = 'rare',
  route_tags = { 'element', 'flame_arrow' },
  compose_inputs = {},
  compose_hint = '为元素共鸣的爆炎箭提供点燃效果。',
  bond_effect_desc = '爆炎箭命中和爆炸都附带点燃（4 秒），每秒造成 12% 攻击伤害；每 6.5 秒额外打出 1 次灼羽齐射。',
  runtime = {
    ignite_duration = 4,
    ignite_tick_ratio = 0.12,
  },
}
