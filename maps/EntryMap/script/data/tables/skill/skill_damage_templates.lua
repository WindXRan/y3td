local list = {
  { id = 'single', name = '单体直伤', summary = '命中单个目标并结算一次伤害。', max_hits = 'max' },
  { id = 'area_burst', name = '范围爆发', summary = '在半径区域内对所有命中目标结算同一段伤害。', max_hits = 'max' },
  { id = 'line_pierce', name = '直线穿透', summary = '在起点到终点的线段宽度内逐个结算伤害。', max_hits = 'max' },
  { id = 'beam_tick', name = '光束多段', summary = '沿线周期性多次结算伤害，适合持续引导技能。', max_hits = 'max' },
  { id = 'chain_bounce', name = '弹射连锁', summary = '按目标链条顺序对多个单位依次结算伤害。', max_hits = 'max' },
  { id = 'field_tick', name = '领域持续', summary = '在固定或移动区域内按 Tick 周期持续结算伤害。', max_hits = 'max' },
}

local by_id = {}
for _, entry in ipairs(list) do by_id[entry.id] = entry end

local cast_family_map = {
  line = 'line_pierce', line_return = 'line_pierce', beam = 'beam_tick', chain = 'chain_bounce',
  area_burst = 'area_burst', delayed_area_burst = 'area_burst', seal_burst = 'area_burst', nova = 'area_burst',
  persistent_field = 'field_tick', moving_field = 'field_tick', control_field = 'field_tick', ignite_field = 'field_tick',
  seeking_swords = 'chain_bounce',
}

return {
  list = list, by_id = by_id, cast_family_map = cast_family_map, default_template_id = 'single',
}