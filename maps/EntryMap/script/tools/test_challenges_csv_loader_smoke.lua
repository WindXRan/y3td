package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.challenges'

assert(type(mod) == 'table', 'challenges object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')

assert(#mod.list == 4, 'expected 4 challenges')

local gold_trial = mod.by_id.gold_trial
assert(gold_trial, 'expected gold_trial to exist')
assert(gold_trial.name == '金币挑战', 'expected gold_trial name to match')
assert(gold_trial.hotkey == 'Q', 'expected gold_trial hotkey to match')
assert(gold_trial.duration_sec > 0, 'expected scaled duration_sec to be positive')
assert(gold_trial.reward.gold == 260, 'expected gold_trial gold reward to match')
assert(gold_trial.reward.wood == 0, 'expected gold_trial wood reward to match')
assert(type(gold_trial.batches) == 'table' and #gold_trial.batches == 1, 'expected gold_trial to have 1 batch')
assert(gold_trial.batches[1].count == 10, 'expected gold_trial batch count to match')

local treasure_trial = mod.by_id.treasure_trial
assert(treasure_trial, 'expected treasure_trial to exist')
assert(treasure_trial.reward.gold == 60, 'expected treasure_trial gold reward to match')
assert(treasure_trial.reward.wood == 30, 'expected treasure_trial wood reward to match')
assert(treasure_trial.boss_unit_id == 134228855, 'expected treasure_trial boss_unit_id to match')
assert(treasure_trial.guard_unit_id == 134241735, 'expected treasure_trial guard_unit_id to match')
assert(treasure_trial.unit_id == nil, 'expected treasure_trial unit_id to stay nil')

print('[OK] challenges csv loader smoke passed')
