local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local wave_rows = CsvLoader.read_rows('data_csv/waves.csv')

local DEBUG_TIME_SCALE = ((y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode()) and 0.2) or 1.0

local function scale(seconds)
  return (seconds or 0) * DEBUG_TIME_SCALE
end

local function segment(start_sec, interval_sec)
  return {
    start_sec = scale(start_sec),
    interval_sec = scale(interval_sec),
  }
end

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local function build_segments(row)
  local result = {}
  for index = 1, 3 do
    local start_sec = row['segment' .. index .. '_start_sec']
    local interval_sec = row['segment' .. index .. '_interval_sec']
    if start_sec ~= nil and start_sec ~= '' and interval_sec ~= nil and interval_sec ~= '' then
      result[#result + 1] = segment(tonumber(start_sec) or 0, tonumber(interval_sec) or 0)
    end
  end
  return result
end

local function build_attr_overrides(row)
  local result = {}
  if row.main_attr_override_name ~= nil and row.main_attr_override_name ~= '' then
    result[row.main_attr_override_name] = tonumber(row.main_attr_override_value) or 0
  end
  return next(result) and result or nil
end

local function build_reward(row, prefix)
  return {
    exp = tonumber(row[prefix .. '_exp']) or 0,
    gold = tonumber(row[prefix .. '_gold']) or 0,
    wood = tonumber(row[prefix .. '_wood']) or 0,
  }
end

local list = {}
for _, row in ipairs(wave_rows) do
  list[#list + 1] = {
    id = row.id,
    index = tonumber(row.index) or 0,
    name = row.name,
    main_unit_id = tonumber(row.main_unit_id) or 0,
    boss_unit_id = tonumber(row.boss_unit_id) or 0,
    spawn_area_id = row.spawn_area_id,
    boss_spawn_area_id = row.boss_spawn_area_id,
    boss_spawn_sec = scale(tonumber(row.boss_spawn_sec) or 0),
    batch_min = tonumber(row.batch_min) or 0,
    batch_max = tonumber(row.batch_max) or 0,
    max_alive = tonumber(row.max_alive) or 0,
    spawn_segments = build_segments(row),
    post_boss_interval_sec = scale(tonumber(row.post_boss_interval_sec) or 0),
    main_attr_overrides = build_attr_overrides(row),
    main_spawn_hp = to_optional_number(row.main_spawn_hp),
    main_kill_reward = build_reward(row, 'main_kill_reward'),
    boss_kill_reward = build_reward(row, 'boss_kill_reward'),
    boss_special = row.boss_special ~= '' and row.boss_special or nil,
    theme = row.theme ~= '' and row.theme or nil,
    boss_timeline_profile_id = row.boss_timeline_profile_id ~= '' and row.boss_timeline_profile_id or nil,
    boss_low_hp_profile_id = row.boss_low_hp_profile_id ~= '' and row.boss_low_hp_profile_id or nil,
  }
end

table.sort(list, function(a, b)
  return (a.index or 0) < (b.index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
