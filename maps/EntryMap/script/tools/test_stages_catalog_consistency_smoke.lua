package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local stages = (require 'data.game_tables').stages
local stage_modes = (require 'data.game_tables').stage_modes

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

for _, stage in ipairs(stages.list) do
  local seen_modes = {}
  assert(type(stage.mode_ids) == 'table' and #stage.mode_ids > 0, 'expected stage mode_ids: ' .. tostring(stage.id))
  for _, mode_id in ipairs(stage.mode_ids) do
    assert(mode_ids[mode_id] ~= nil, 'expected stage mode to exist: ' .. tostring(mode_id))
    assert(seen_modes[mode_id] == nil, 'expected unique mode per stage: ' .. tostring(stage.id))
    seen_modes[mode_id] = true
  end
end

print('[OK] stages catalog consistency smoke passed')


