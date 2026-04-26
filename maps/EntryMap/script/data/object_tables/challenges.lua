local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local challenge_rows = CsvLoader.read_rows('data_csv/challenges.csv')

local DEBUG_TIME_SCALE = ((y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode()) and 0.2) or 1.0

local function scale(seconds)
  return (seconds or 0) * DEBUG_TIME_SCALE
end

local function challenge_batch(time_sec, count)
  return {
    time_sec = scale(time_sec),
    count = count,
  }
end

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local function build_reward(row, prefix)
  prefix = prefix or 'reward_'
  return {
    gold = tonumber(row[prefix .. 'gold']) or 0,
    wood = tonumber(row[prefix .. 'wood']) or 0,
    exp = tonumber(row[prefix .. 'exp']) or 0,
    special = row[prefix .. 'special'] ~= '' and row[prefix .. 'special'] or nil,
  }
end

local function build_batches(row)
  local count = tonumber(row.batch_count) or 0
  if count <= 0 then
    return {}
  end
  return {
    challenge_batch(tonumber(row.batch_time_sec) or 0, count),
  }
end

local list = {}
for _, row in ipairs(challenge_rows) do
  list[#list + 1] = {
    id = row.id,
    name = row.name,
    hotkey = row.hotkey ~= '' and row.hotkey or nil,
    duration_sec = scale(tonumber(row.duration_sec) or 0),
    recover_sec = scale(tonumber(row.recover_sec) or 0),
    cost_charge = tonumber(row.cost_charge) or 0,
    spawn_area_id = row.spawn_area_id,
    reward = build_reward(row, 'reward_'),
    kill_reward = build_reward(row, 'kill_reward_'),
    unit_id = to_optional_number(row.unit_id),
    boss_unit_id = to_optional_number(row.boss_unit_id),
    guard_unit_id = to_optional_number(row.guard_unit_id),
    batches = build_batches(row),
    order_index = tonumber(row.order_index) or 0,
  }
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
