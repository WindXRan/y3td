local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local challenge_rows = CsvLoader.read_rows('data_csv/challenges.csv')
local batch_rows = CsvLoader.read_rows('data_csv/challenge_batches.csv')
local batch_groups = CsvLoader.group_by(batch_rows, 'challenge_id')

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

local function build_reward(row)
  return {
    gold = tonumber(row.reward_gold) or 0,
    wood = tonumber(row.reward_wood) or 0,
    exp = tonumber(row.reward_exp) or 0,
    special = row.reward_special ~= '' and row.reward_special or nil,
  }
end

local function build_batches(challenge_id)
  local result = {}
  local rows = {}

  for _, row in ipairs(batch_groups[challenge_id] or {}) do
    rows[#rows + 1] = {
      batch_index = tonumber(row.batch_index) or 0,
      time_sec = tonumber(row.time_sec) or 0,
      count = tonumber(row.count) or 0,
    }
  end

  table.sort(rows, function(a, b)
    return a.batch_index < b.batch_index
  end)

  for _, row in ipairs(rows) do
    result[#result + 1] = challenge_batch(row.time_sec, row.count)
  end

  return result
end

local list = {}
for _, row in ipairs(challenge_rows) do
  list[#list + 1] = {
    id = row.id,
    name = row.name,
    hotkey = row.hotkey ~= '' and row.hotkey or nil,
    duration_sec = scale(tonumber(row.duration_sec) or 0),
    cost_charge = tonumber(row.cost_charge) or 0,
    spawn_area_id = row.spawn_area_id,
    reward = build_reward(row),
    unit_id = to_optional_number(row.unit_id),
    boss_unit_id = to_optional_number(row.boss_unit_id),
    guard_unit_id = to_optional_number(row.guard_unit_id),
    batches = build_batches(row.id),
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
