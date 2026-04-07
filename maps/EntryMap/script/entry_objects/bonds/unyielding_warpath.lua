return {
  id = 'unyielding_warpath',
  name = '不屈战意',
  quality = 'epic',
  required_count = 1,
  pool_weight = 0,
  tier = 't2',
  bond_role = 'mother',
  result_type = 'terminal_swallow',
  target_quality = 'epic',
  route_tags = { 'low_hp', 'basic_attack' },
  compose_inputs = { 'berserk', 'blood_pact', 'growth' },
  compose_hint = '狂战 + 血契 + 成长 自动合成。',
  is_recipe_only = true,
  bond_effect_desc = '物理吸血 +10%，攻击速度 +20，全伤害 +12%，普攻伤害 +20%。',
  attr = {
    ['物理吸血'] = 10,
    ['攻击速度'] = 20,
  },
  runtime = {
    all_damage_bonus = 0.12,
    normal_attack_damage_bonus = 0.20,
  },
}
