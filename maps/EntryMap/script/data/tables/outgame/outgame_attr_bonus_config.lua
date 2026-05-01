local AttrEffect = require 'data.tables.attreffect'

local rows = AttrEffect.by_source.outgame_bonus or {}

local list = {}
local by_stage_mode = {}

for source_id, bucket in pairs(rows) do
  local stage_id, mode_id = tostring(source_id):match('^(.-):(.-)$')
  assert(stage_id ~= nil and mode_id ~= nil, 'invalid outgame_bonus source_id: ' .. tostring(source_id))

  by_stage_mode[stage_id] = by_stage_mode[stage_id] or {}
  by_stage_mode[stage_id][mode_id] = by_stage_mode[stage_id][mode_id] or {}

  for _, row in ipairs(bucket.ordered or {}) do
    if row.effect_kind == 'attr' then
      local entry = {
        stage_id = stage_id,
        mode_id = mode_id,
        order_index = row.order_index,
        attr_name = row.effect_key,
        value = row.value,
      }
      list[#list + 1] = entry
      by_stage_mode[stage_id][mode_id][row.effect_key] = (by_stage_mode[stage_id][mode_id][row.effect_key] or 0) + row.value
    end
  end
end

table.sort(list, function(a, b)
  if a.order_index == b.order_index then
    if a.stage_id == b.stage_id then
      if a.mode_id == b.mode_id then
        return a.attr_name < b.attr_name
      end
      return a.mode_id < b.mode_id
    end
    return a.stage_id < b.stage_id
  end
  return a.order_index < b.order_index
end)

return {
  list = list,
  by_stage_mode = by_stage_mode,
}

