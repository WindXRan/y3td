package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local CsvLoader = require 'data.csv_loader'
local stages = require 'data.object_tables.stages'
local stage_modes = require 'data.object_tables.stage_modes'

local link_rows = CsvLoader.read_rows('data_csv/stage_mode_links.csv')

assert(type(stages.list) == 'table', 'stages.list should be a table')
assert(type(stage_modes.list) == 'table', 'stage_modes.list should be a table')

local stage_ids = {}
local mode_ids = {}

for _, stage in ipairs(stages.list) do
  assert(stage.id ~= nil and stage.id ~= '', 'expected stage id')
  assert(stage.order_index ~= nil and stage.order_index > 0, 'expected stage order_index')
  assert(stage.stage_id ~= nil and stage.stage_id ~= '', 'expected stage_id')
  assert(stage.content_source_stage_id ~= nil and stage.content_source_stage_id ~= '', 'expected content_source_stage_id')
  assert(stage_ids[stage.id] == nil, 'expected unique stage id: ' .. tostring(stage.id))
  stage_ids[stage.id] = stage
end

for _, mode in ipairs(stage_modes.list) do
  assert(mode.id ~= nil and mode.id ~= '', 'expected mode id')
  assert(mode.order_index ~= nil and mode.order_index > 0, 'expected mode order_index')
  assert(mode.mode_id ~= nil and mode.mode_id ~= '', 'expected mode_id')
  assert(mode_ids[mode.id] == nil, 'expected unique mode id: ' .. tostring(mode.id))
  mode_ids[mode.id] = mode
end

local link_groups = {}
for _, row in ipairs(link_rows) do
  assert(row.stage_id ~= nil and row.stage_id ~= '', 'expected stage_mode_links stage_id')
  assert(row.mode_id ~= nil and row.mode_id ~= '', 'expected stage_mode_links mode_id')
  assert(row.order_index ~= nil and row.order_index ~= '', 'expected stage_mode_links order_index')
  assert(stage_ids[row.stage_id] ~= nil, 'expected link stage to exist: ' .. tostring(row.stage_id))
  assert(mode_ids[row.mode_id] ~= nil, 'expected link mode to exist: ' .. tostring(row.mode_id))
  link_groups[row.stage_id] = link_groups[row.stage_id] or {}
  link_groups[row.stage_id][#link_groups[row.stage_id] + 1] = {
    order_index = tonumber(row.order_index) or 0,
    mode_id = row.mode_id,
  }
end

for _, stage in ipairs(stages.list) do
  local links = link_groups[stage.id] or {}
  assert(#links == #stage.mode_ids, 'expected stage mode count to match links: ' .. tostring(stage.id))

  table.sort(links, function(a, b)
    if a.order_index == b.order_index then
      return tostring(a.mode_id) < tostring(b.mode_id)
    end
    return a.order_index < b.order_index
  end)

  local seen_orders = {}
  local seen_modes = {}
  for index, link in ipairs(links) do
    assert(link.order_index > 0, 'expected positive link order_index: ' .. tostring(stage.id))
    assert(seen_orders[link.order_index] == nil, 'expected unique link order_index per stage: ' .. tostring(stage.id))
    assert(seen_modes[link.mode_id] == nil, 'expected unique link mode per stage: ' .. tostring(stage.id))
    assert(stage.mode_ids[index] == link.mode_id, 'expected stage.mode_ids to match ordered links: ' .. tostring(stage.id))
    seen_orders[link.order_index] = true
    seen_modes[link.mode_id] = true
  end
end

print('[OK] stages catalog consistency smoke passed')
