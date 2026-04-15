local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local rows = CsvLoader.read_rows('data_csv/stage_modes.csv')

local list = {}
for _, row in ipairs(rows) do
  list[#list + 1] = {
    id = row.id,
    mode_id = row.mode_id,
    order_index = tonumber(row.order_index) or 0,
    display_name = row.display_name,
    unlock_rule = row.unlock_rule,
    ui_badge_text = row.ui_badge_text,
    battle_config_key = row.battle_config_key,
    result_bucket = row.result_bucket,
  }
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
