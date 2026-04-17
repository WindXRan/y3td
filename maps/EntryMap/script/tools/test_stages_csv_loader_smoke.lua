package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local stages = require 'data.object_tables.stages'

assert(type(stages.list) == 'table', 'stages.list should be a table')
assert(type(stages.by_id) == 'table', 'stages.by_id should be a table')
assert(#stages.list == 75, 'expected 75 stages')

local stage_1_1 = stages.by_id['1-1']
assert(stage_1_1 ~= nil, 'stage 1-1 should exist')
assert(stage_1_1.stage_id == '1-1', 'stage 1-1 should keep stage_id')
assert(stage_1_1.order_index == 1, 'stage 1-1 should keep order_index')
assert(stage_1_1.display_name == '花果山洞-1', 'stage 1-1 should use the themed chapter label')
assert(type(stage_1_1.mode_ids) == 'table', 'stage 1-1 mode_ids should be a table')
assert(#stage_1_1.mode_ids == 1, 'stage 1-1 should keep one mode id')
assert(stage_1_1.mode_ids[1] == 'standard', 'stage 1-1 should keep standard mode')
assert(stage_1_1.content_source_stage_id == '1-1', 'stage 1-1 should keep its own content source')

local stage_2_1 = stages.by_id['2-1']
assert(stage_2_1 ~= nil, 'stage 2-1 should exist')
assert(stage_2_1.display_name == '天庭殿前-1', 'stage 2-1 should use the second chapter label')
assert(stage_2_1.order_index == 16, 'stage 2-1 should continue the global ordering')
assert(stage_2_1.content_source_stage_id == '1-1', 'stage 2-1 should currently reuse the 1-1 battle content')

local stage_5_15 = stages.by_id['5-15']
assert(stage_5_15 ~= nil, 'stage 5-15 should exist')
assert(stage_5_15.display_name == '灵山寺下-15', 'stage 5-15 should use the fifth chapter label')
assert(stage_5_15.order_index == 75, 'stage 5-15 should be the final configured stage')
assert(#stage_5_15.mode_ids == 1, 'stage 5-15 should keep one mode id')
assert(stage_5_15.mode_ids[1] == 'standard', 'stage 5-15 should keep standard mode')

print('stages csv loader smoke ok')
