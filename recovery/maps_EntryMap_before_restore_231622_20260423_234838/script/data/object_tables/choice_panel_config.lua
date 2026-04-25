local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows('data_csv/choice_panel_config.csv')

local refresh_costs = {}
local refresh_cost_default = 0

local badge_text_by_quality = {}

for _, row in ipairs(rows) do
  if row.record_type == 'refresh_cost' then
    local paid_count = tonumber(row.key) or 0
    local wood_cost = tonumber(row.value) or 0
    refresh_costs[paid_count] = wood_cost
    if paid_count >= 0 then
      refresh_cost_default = wood_cost
    end
  elseif row.record_type == 'badge_text' then
    badge_text_by_quality[row.key] = row.value
  end
end

return {
  refresh_costs = refresh_costs,
  refresh_cost_default = refresh_cost_default,
  badge_text_by_quality = badge_text_by_quality,
}
