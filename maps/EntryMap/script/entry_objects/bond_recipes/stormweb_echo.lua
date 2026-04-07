return {
  id = 'stormweb_echo',
  output_bond_id = 'stormweb_echo',
  output_tier = 't2',
  output_quality = 'epic',
  input_bond_ids = { 'chain', 'shock', 'tailwind' },
  consume_inputs = true,
  result_type = 'terminal_swallow',
  route_tags = { 'chain', 'clear' },
  priority = 20,
  ui_recipe_desc = '连锁 + 感电 + 追风 -> 雷网回响',
}
