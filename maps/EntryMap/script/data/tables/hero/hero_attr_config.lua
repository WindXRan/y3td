local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows('data_csv/hero_attr_config.csv')
local hero_init_rows = CsvLoader.read_rows('data_csv/hero_init_stats.csv')

local function read_scalar_map(scope)
  local result = {}
  for _, row in ipairs(rows) do
    if row.scope == scope then
      result[row.key] = tonumber(row.value) or row.value
    end
  end
  return result
end

local function read_key_value_rows(source_rows)
  local result = {}
  for _, row in ipairs(source_rows or {}) do
    if row.key ~= nil and row.key ~= '' then
      result[row.key] = tonumber(row.value) or row.value
    end
  end
  return result
end

local panel_default_attrs = read_scalar_map('panel_default')
local hero_init_stats = read_key_value_rows(hero_init_rows)

for key, value in pairs(panel_default_attrs) do
  if hero_init_stats[key] == nil then
    hero_init_stats[key] = value
  end
end

return {
  panel_default_attrs = panel_default_attrs,
  hero_init_stats = hero_init_stats,
  debug_hero_bonus_stats = read_scalar_map('debug_bonus'),
}
