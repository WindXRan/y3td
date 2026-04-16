local CsvLoader = require 'data.csv_loader'

local slot_rows = CsvLoader.read_rows('data_csv/gear_upgrade_slots.csv')
local level_rows = CsvLoader.read_rows('data_csv/gear_upgrade_levels.csv')

local function to_boolean(raw)
  return raw == 'true' or raw == '1'
end

local slots = {}
for _, row in ipairs(slot_rows) do
  slots[row.slot] = {
    slot = row.slot,
    order_index = tonumber(row.order_index) or 0,
    display_name = row.display_name,
    max_level = tonumber(row.max_level) or 0,
    affix_choice_count = tonumber(row.affix_choice_count) or 0,
    item_key = tonumber(row.item_key) or row.item_key,
  }
end

local levels = {}
local levels_by_level = {}
for _, row in ipairs(level_rows) do
  local entry = {
    level = tonumber(row.level) or 0,
    order_index = tonumber(row.order_index) or 0,
    gold_cost = tonumber(row.gold_cost) or 0,
    is_affix_node = to_boolean(row.is_affix_node),
  }
  levels[#levels + 1] = entry
  levels_by_level[entry.level] = entry
end

table.sort(levels, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  slots = slots,
  levels = levels,
  levels_by_level = levels_by_level,
}
