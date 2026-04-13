local CsvLoader = require 'data.csv_loader'

local function read_scalar_map(path)
  local rows = CsvLoader.read_rows(path)
  local result = {}
  for _, row in ipairs(rows) do
    result[row.key] = tonumber(row.value) or row.value
  end
  return result
end

local panel_default_attrs = read_scalar_map('data_csv/panel_default_attrs.csv')
local hero_init_stats = read_scalar_map('data_csv/hero_init_stats.csv')

for key, value in pairs(panel_default_attrs) do
  if hero_init_stats[key] == nil then
    hero_init_stats[key] = value
  end
end

return {
  panel_default_attrs = panel_default_attrs,
  hero_init_stats = hero_init_stats,
  debug_hero_bonus_stats = read_scalar_map('data_csv/debug_hero_bonus_stats.csv'),
}
