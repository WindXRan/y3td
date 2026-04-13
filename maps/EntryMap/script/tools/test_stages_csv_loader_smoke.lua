package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local stages = require 'data.object_tables.stages'

assert(type(stages.list) == 'table', 'stages.list should be a table')
assert(type(stages.by_id) == 'table', 'stages.by_id should be a table')
assert(#stages.list == 3, 'expected 3 stages')

local stage_1_1 = stages.by_id['1-1']
assert(stage_1_1 ~= nil, 'stage 1-1 should exist')
assert(stage_1_1.stage_id == '1-1', 'stage 1-1 should keep stage_id')
assert(stage_1_1.order_index == 1, 'stage 1-1 should keep order_index')
assert(type(stage_1_1.mode_ids) == 'table', 'stage 1-1 mode_ids should be a table')
assert(#stage_1_1.mode_ids == 2, 'stage 1-1 should keep two mode ids')
assert(stage_1_1.mode_ids[1] == 'standard', 'stage 1-1 should keep standard mode first')
assert(stage_1_1.mode_ids[2] == 'challenge', 'stage 1-1 should keep challenge mode second')

print('stages csv loader smoke ok')
