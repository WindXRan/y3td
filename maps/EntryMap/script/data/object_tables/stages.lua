local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local stage_rows = CsvLoader.read_rows('data_csv/stages.csv')

local function split_mode_ids(raw)
  local mode_ids = {}
  for mode_id in tostring(raw or ''):gmatch('[^|]+') do
    if mode_id ~= '' then
      mode_ids[#mode_ids + 1] = mode_id
    end
  end
  if #mode_ids == 0 then
    mode_ids[1] = 'standard'
  end
  return mode_ids
end

local list = {}
for _, row in ipairs(stage_rows) do
  list[#list + 1] = {
    id = row.id,
    stage_id = row.stage_id,
    display_name = row.display_name,
    order_index = tonumber(row.order_index) or 0,
    content_source_stage_id = row.content_source_stage_id,
    mode_ids = split_mode_ids(row.mode_ids),
    preview_note = row.preview_note ~= '' and row.preview_note or nil,
    -- N0 自动验收可选策略：
    -- all: 激活全部羁绊特殊效果；single: 仅激活一个；none: 不自动激活。
    n0_activation_mode = row.n0_activation_mode ~= '' and row.n0_activation_mode or nil,
    -- 当 n0_activation_mode=single 时优先使用；为空则按 run_id 自动轮换一个羁绊。
    n0_single_bond = row.n0_single_bond ~= '' and row.n0_single_bond or nil,
    -- N0 开局是否做“无冷却预热”（召唤/周期技可立即触发）。
    n0_opening_no_cooldown = row.n0_opening_no_cooldown ~= '' and row.n0_opening_no_cooldown or nil,
  }
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
