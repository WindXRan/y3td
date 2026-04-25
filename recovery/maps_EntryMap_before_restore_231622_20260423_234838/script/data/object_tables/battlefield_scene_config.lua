local CsvLoader = require 'data.csv_loader'

local function to_number(value)
  return tonumber(value) or value
end

local rows = CsvLoader.read_rows('data_csv/battlefield_scene_config.csv')

local function read_points(rows)
  local result = {}
  for _, row in ipairs(rows) do
    if row.record_type == 'point' then
      result[row.id] = {
        x = to_number(row.x),
        y = to_number(row.y),
        z = to_number(row.z),
      }
    end
  end
  return result
end

local function read_areas(rows)
  local result = {}
  for _, row in ipairs(rows) do
    if row.record_type == 'area' then
      result[row.id] = {
        x_min = to_number(row.x_min),
        x_max = to_number(row.x_max),
        y_min = to_number(row.y_min),
        y_max = to_number(row.y_max),
        z = to_number(row.value),
      }
    end
  end
  return result
end

local function read_slow_zones(rows)
  local filtered = {}
  for _, row in ipairs(rows) do
    if row.record_type == 'slow_zone' then
      filtered[#filtered + 1] = row
    end
  end
  table.sort(filtered, function(a, b)
    return (tonumber(a.order_index) or 0) < (tonumber(b.order_index) or 0)
  end)
  local result = {}
  for _, row in ipairs(filtered) do
    result[#result + 1] = {
      area_id = row.ref_id,
      speed_factor = to_number(row.speed_factor),
    }
  end
  return result
end

local function read_scalar_map(rows)
  local result = {}
  for _, row in ipairs(rows) do
    if row.record_type == 'save_slot' then
      result[row.id] = to_number(row.value)
    end
  end
  return result
end

return {
  points = read_points(rows),
  areas = read_areas(rows),
  main_enemy_slow_zones = read_slow_zones(rows),
  save_slots = read_scalar_map(rows),
}
