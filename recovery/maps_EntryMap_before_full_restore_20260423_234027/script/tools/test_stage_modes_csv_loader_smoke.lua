package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local stage_modes = require 'data.object_tables.stage_modes'

assert(type(stage_modes.list) == 'table', 'stage_modes.list should be a table')
assert(type(stage_modes.by_id) == 'table', 'stage_modes.by_id should be a table')
assert(#stage_modes.list == 2, 'expected 2 stage modes')

local standard = stage_modes.by_id.standard
assert(standard ~= nil, 'standard mode should exist')
assert(standard.mode_id == 'standard', 'standard mode should keep mode_id')
assert(standard.unlock_rule == 'stage_standard_unlocked', 'standard mode should keep unlock_rule')

local challenge = stage_modes.by_id.challenge
assert(challenge ~= nil, 'challenge mode should exist')
assert(challenge.result_bucket == 'challenge', 'challenge mode should keep result_bucket')

print('stage_modes csv loader smoke ok')
