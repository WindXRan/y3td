package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'data.object_tables.waves'

assert(type(mod) == 'table', 'waves object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')

assert(#mod.list == 5, 'expected 5 waves')

local wave_1 = mod.by_id.wave_1
assert(wave_1, 'expected wave_1 to exist')
assert(wave_1.name == '第1波：饥饿地精', 'expected wave_1 name to match')
assert(wave_1.index == 1, 'expected wave_1 index to match')
assert(wave_1.main_unit_id == 200009, 'expected wave_1 main_unit_id to match')
assert(wave_1.boss_unit_id == 400009, 'expected wave_1 boss_unit_id to match')
assert(type(wave_1.spawn_segments) == 'table' and #wave_1.spawn_segments == 3, 'expected wave_1 to have 3 spawn segments')
assert(wave_1.spawn_segments[1].start_sec == 0, 'expected wave_1 first segment start_sec to match')
assert(wave_1.main_attr_overrides['最大生命'] == 1, 'expected wave_1 main_attr_overrides to be preserved')
assert(wave_1.main_spawn_hp == 1, 'expected wave_1 main_spawn_hp to be preserved')
assert(wave_1.main_kill_reward.exp == 8, 'expected wave_1 main_kill_reward exp to match')

local wave_5 = mod.by_id.wave_5
assert(wave_5, 'expected wave_5 to exist')
assert(wave_5.theme == '终盘高压', 'expected wave_5 theme to match')
assert(wave_5.boss_special == '胜利结算', 'expected wave_5 boss_special to match')
assert(wave_5.boss_kill_reward.wood == 40, 'expected wave_5 boss_kill_reward wood to match')

print('[OK] waves csv loader smoke passed')
