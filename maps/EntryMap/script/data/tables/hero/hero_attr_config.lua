local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows({path = 'data_csv/hero_init_stats.csv'})

local function read_key_value_rows(source_rows)
  local result = {}
  local debug_stats = {}
  for _, row in ipairs(source_rows or {}) do
    if row.key ~= nil and row.key ~= '' and row.key ~= '__字段说明__' then
      local value = tonumber(row.value) or row.value
      if string.sub(row.key, 1, 6) == 'debug_' then
        local debug_key = string.sub(row.key, 7)
        debug_stats[debug_key] = value
      else
        result[row.key] = value
      end
    end
  end
  return result, debug_stats
end

local hero_init_stats, debug_hero_bonus_stats = read_key_value_rows(rows)

return {
  panel_default_attrs = hero_init_stats,
  hero_init_stats = hero_init_stats,
  debug_hero_bonus_stats = debug_hero_bonus_stats,
}