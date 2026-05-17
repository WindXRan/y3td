local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows_optional({path = 'data_csv/buff_templates.csv'})

local M = {
  list = {},
  by_id = {},
  by_key = {},
  buffs = {},
  debuffs = {},
  by_category = {},
}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function parse_enabled(raw)
  local value = string.lower(trim(raw))
  return value == '' or value == '1' or value == 'true'
end

local function parse_show_on_ui(raw)
  return trim(raw) == '1' or string.lower(trim(raw)) == 'true'
end

for _, row in ipairs(rows or {}) do
  if parse_enabled(row.enabled) then
    local entry = {
      id = trim(row.id),
      modifier_key = tonumber(row.modifier_key) or 0,
      name = trim(row.name),
      description = trim(row.description),
      buff_type = trim(row.buff_type),
      effect_category = trim(row.effect_category),
      modifier_effect_type = tonumber(row.modifier_effect_type) or 1,
      modifier_type = tonumber(row.modifier_type) or 1,
      duration = tonumber(row.duration) or -1,
      max_stacks = tonumber(row.max_stacks) or 1,
      cycle_time = tonumber(row.cycle_time) or 0,
      icon_id = tonumber(row.icon_id) or 100008,
      attr_name = trim(row.attr_name),
      attr_value = tonumber(row.attr_value) or 0,
      material_color = {
        tonumber(row.material_color_r) or 255,
        tonumber(row.material_color_g) or 255,
        tonumber(row.material_color_b) or 255,
      },
      show_on_ui = parse_show_on_ui(row.show_on_ui),
      state_name = trim(row.state_name),
      notes = trim(row.notes),
    }
    M.list[#M.list + 1] = entry
    if entry.id ~= '' then
      M.by_id[entry.id] = entry
    end
    if entry.modifier_key > 0 then
      M.by_key[entry.modifier_key] = entry
    end
    if entry.buff_type ~= '' then
      local group = M[entry.buff_type .. 's']
      if not group then
        group = {}
        M[entry.buff_type .. 's'] = group
      end
      group[#group + 1] = entry
    end
    if entry.effect_category ~= '' then
      M.by_category[entry.effect_category] = M.by_category[entry.effect_category] or {}
      M.by_category[entry.effect_category][#M.by_category[entry.effect_category] + 1] = entry
    end
  end
end

return M
