local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local rows = CsvLoader.read_rows('data_csv/mainline_task_rewards.csv')

local function build_reward_lines(row)
  local lines = {}
  for index = 1, 3 do
    local prefix = 'reward_' .. index .. '_'
    local reward_type = row[prefix .. 'type']
    local reward_key = row[prefix .. 'key']
    local reward_value = tonumber(row[prefix .. 'value'])
    if reward_type ~= '' and reward_key ~= '' and reward_value ~= nil then
      lines[#lines + 1] = {
        slot = index,
        type = reward_type,
        key = reward_key,
        value = reward_value,
      }
    end
  end
  return lines
end

local list = {}
for _, row in ipairs(rows) do
  list[#list + 1] = {
    id = row.id,
    chapter_id = tonumber(row.chapter_id) or 0,
    order_index = tonumber(row.order_index) or 0,
    title_text = row.title_text,
    objective_text = row.objective_text,
    target_count = tonumber(row.target_count) or 0,
    reward_lines = build_reward_lines(row),
  }
end

table.sort(list, function(a, b)
  if (a.chapter_id or 0) == (b.chapter_id or 0) then
    return (a.order_index or 0) < (b.order_index or 0)
  end
  return (a.chapter_id or 0) < (b.chapter_id or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
