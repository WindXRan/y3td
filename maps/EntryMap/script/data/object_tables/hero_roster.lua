local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local roster_rows = CsvLoader.read_rows('data_csv/hero_roster.csv')

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local list = {}
for _, row in ipairs(roster_rows) do
  list[#list + 1] = {
    id = row.id,
    order_index = tonumber(row.order_index) or 0,
    rarity = row.rarity,
    name = row.name,
    title = row.title,
    unit_id = to_optional_number(row.unit_id),
    carrier_name = row.carrier_name,
    skill_id = row.skill_id,
    summary = row.summary,
  }
end

table.sort(list, function(a, b)
  local a_order = a.order_index or 0
  local b_order = b.order_index or 0
  if a_order == b_order then
    return tostring(a.id or '') < tostring(b.id or '')
  end
  return a_order < b_order
end)

local by_id = helpers.list_to_map(list)
local by_unit_id = {}
for _, entry in ipairs(list) do
  if entry.unit_id ~= nil then
    by_unit_id[entry.unit_id] = entry
  end
end

return {
  list = list,
  by_id = by_id,
  by_unit_id = by_unit_id,
}
