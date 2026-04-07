return {
  id = 'holy_bastion',
  name = '圣愈壁垒',
  quality = 'epic',
  required_count = 1,
  pool_weight = 0,
  tier = 't2',
  bond_role = 'mother',
  result_type = 'terminal_swallow',
  target_quality = 'epic',
  route_tags = { 'survival', 'boss' },
  compose_inputs = { 'blessing', 'fortress', 'guardian' },
  compose_hint = '祝福 + 坚壁 + 守护 自动合成。',
  is_recipe_only = true,
  bond_effect_desc = '最大生命 +320，伤害减免 +12%，对精英与 Boss 伤害额外 +20%。',
  attr = {
    ['最大生命'] = 320,
    ['伤害减免'] = 12,
  },
  runtime = {
    boss_damage_bonus = 0.20,
    elite_damage_bonus = 0.20,
  },
}
