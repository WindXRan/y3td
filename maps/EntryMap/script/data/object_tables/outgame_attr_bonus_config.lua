local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows('data_csv/outgame_attr_bonuses.csv')

local list = {}
local by_stage_mode = {}

for _, row in ipairs(rows) do
  local entry = {
    stage_id = row.stage_id,
    mode_id = row.mode_id,
    order_index = tonumber(row.order_index) or 0,
    attr_name = row.attr_name,
    value = tonumber(row.value) or 0,
  }
  list[#list + 1] = entry

  by_stage_mode[entry.stage_id] = by_stage_mode[entry.stage_id] or {}
  by_stage_mode[entry.stage_id][entry.mode_id] = by_stage_mode[entry.stage_id][entry.mode_id] or {}
  local bucket = by_stage_mode[entry.stage_id][entry.mode_id]
  bucket[entry.attr_name] = (bucket[entry.attr_name] or 0) + entry.value
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
