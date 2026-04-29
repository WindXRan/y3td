package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.challenges'

assert(type(mod) == 'table', 'challenges object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')

assert(#mod.list == 3, 'expected 3 challenges')

local gold_trial = mod.by_id.gold_trial
assert(gold_trial, 'expected gold_trial to exist')
assert(gold_trial.name == '金币挑战', 'expected gold_trial name to match')
assert(gold_trial.hotkey == 'Q', 'expected gold_trial hotkey to match')
assert(gold_trial.duration_sec > 0, 'expected scaled duration_sec to be positive')
assert(gold_trial.recover_sec == 75, 'expected gold_trial recover_sec to match')
assert(gold_trial.reward.gold == 260, 'expected gold_trial gold reward to match')
assert(gold_trial.reward.wood == 0, 'expected gold_trial wood reward to match')
assert(gold_trial.kill_reward.gold == 12, 'expected gold_trial kill reward gold to match')
assert(gold_trial.kill_reward.wood == 0, 'expected gold_trial kill reward wood to match')
assert(type(gold_trial.batches) == 'table' and #gold_trial.batches == 1, 'expected gold_trial to have 1 batch')
assert(gold_trial.batches[1].time_sec == 0, 'expected gold_trial batch time to match')
assert(gold_trial.batches[1].count == 4, 'expected gold_trial batch count to match')

local wood_trial = mod.by_id.wood_trial
assert(wood_trial, 'expected wood_trial to exist')
assert(wood_trial.recover_sec == 90, 'expected wood_trial recover_sec to match')
assert(wood_trial.batches[1].count == 4, 'expected wood_trial batch count to match')

local exp_trial = mod.by_id.exp_trial
assert(exp_trial, 'expected exp_trial to exist')
assert(exp_trial.recover_sec == 120, 'expected exp_trial recover_sec to match')
assert(exp_trial.batches[1].count == 4, 'expected exp_trial batch count to match')

assert(mod.by_id.treasure_trial == nil, 'expected treasure_trial to be removed')

print('[OK] challenges csv loader smoke passed')
