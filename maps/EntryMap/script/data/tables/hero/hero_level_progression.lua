local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows({path = 'data_csv/hero_level_progression.csv'})

local list = {}
local by_level = {}

for _, row in ipairs(rows) do
  local entry = {
    level = tonumber(row.level) or 0,
    order_index = tonumber(row.order_index) or 0,
    exp_to_next = tonumber(row.exp_to_next) or 0,
    all_attr_bonus = tonumber(row.all_attr_bonus) or 0,
    all_element_damage_bonus = tonumber(row.all_element_damage_bonus) or 0,
  }
  list[#list + 1] = entry
  by_level[entry.level] = entry
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_level = by_level,
  max_level = #list,
}
