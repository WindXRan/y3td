local CsvLoader = require 'data.csv_loader'

local rule_rows = CsvLoader.read_rows('data_csv/bond_draw_rules.csv')
local refresh_rows = CsvLoader.read_rows('data_csv/bond_refresh_costs.csv')
local group_rows = CsvLoader.read_rows_optional('data_csv/bond_group_choices.csv')
local group_path_rows = CsvLoader.read_rows_optional('data_csv/bond_group_choice_paths.csv')

local draw_cost = 100
for _, row in ipairs(rule_rows) do
  if row.key == 'draw_cost' then
    draw_cost = tonumber(row.value) or draw_cost
  end
end

local refresh_costs = {}
for _, row in ipairs(refresh_rows) do
  local index = tonumber(row.refresh_index) or 0
  if index > 0 then
    refresh_costs[index] = tonumber(row.cost) or 0
  end
end

local group_choice_order = {}
local group_choice_defs = {}
local group_paths_by_id = CsvLoader.group_by(group_path_rows, 'group_id')
table.sort(group_rows, function(a, b)
  return (tonumber(a.order_index) or 0) < (tonumber(b.order_index) or 0)
end)

for _, row in ipairs(group_rows) do
  local path_rows = group_paths_by_id[row.group_id] or {}
  table.sort(path_rows, function(a, b)
    return (tonumber(a.seq) or 0) < (tonumber(b.seq) or 0)
  end)

  local path_parts = {}
  for _, path_row in ipairs(path_rows) do
    if path_row.path_text ~= '' then
      path_parts[#path_parts + 1] = path_row.path_text
    end
  end

  group_choice_order[#group_choice_order + 1] = row.group_id
  group_choice_defs[row.group_id] = {
    id = row.choice_id,
    group_id = row.group_id,
    display_name = row.display_name,
    quality = row.quality,
    path_texts = path_parts,
    desc = #path_parts > 0 and ('解锁：' .. table.concat(path_parts, '；')) or '',
  }
end

return {
  draw_cost = draw_cost,
  refresh_costs = refresh_costs,
  group_choice_order = group_choice_order,
  group_choice_defs = group_choice_defs,
}
