package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local attreffect = require 'data.object_tables.attreffect'
local mod = require 'data.object_tables.mainline_task_rewards'

assert(type(mod) == 'table', 'mainline_task_rewards object table should return a table')
assert(type(mod.list) == 'table', 'mod.list should be a table')
assert(type(mod.by_id) == 'table', 'mod.by_id should be a table')
assert(#mod.list == 40, 'expected 40 mainline task rewards')

local task_11 = mod.by_id['1-1']
local task_effects_11 = attreffect.by_source.mainline_task and attreffect.by_source.mainline_task['1-1']
assert(task_11, 'expected 1-1 task to exist')
assert(task_effects_11 ~= nil, 'expected 1-1 numeric task rows in attreffect')
assert(task_effects_11.attr['攻击范围'] == 100, 'expected canonical attr key for 1-1 in attreffect')
assert(task_effects_11.attr['生命'] == 100, 'expected canonical hp key for 1-1 in attreffect')
assert(task_effects_11.resource['wood'] == 50, 'expected 1-1 resource row in attreffect')
assert(task_11.title_text == '主线1-1', 'expected 1-1 title to match')
assert(task_11.objective_text == '击杀小鬼', 'expected 1-1 objective_text to match')
assert(task_11.target_count == 3, 'expected 1-1 target_count to match')
assert(task_11.spawn_unit_id == 200001, 'expected 1-1 spawn unit to come from explicit task config')
assert(task_11.spawn_area_id == 'challenge_spawn_mid', 'expected 1-1 spawn area to come from explicit task config')
assert(task_11.time_limit == 60, 'expected 1-1 time limit to come from explicit task config')
assert(task_11.is_boss_task == false, 'expected 1-1 to stay marked as a non-boss task')
assert(task_11.reward_lines[1].type == 'attr', 'expected 1-1 reward line 1 type')
assert(task_11.reward_lines[1].key == 'attack_range', 'expected 1-1 reward line 1 key')
assert(task_11.reward_lines[1].value == 100, 'expected 1-1 reward line 1 value')
assert(task_11.reward_lines[3].type == 'resource', 'expected 1-1 reward line 3 type')
assert(task_11.reward_lines[3].key == 'wood', 'expected 1-1 reward line 3 key')
assert(task_11.reward_lines[3].value == 50, 'expected 1-1 reward line 3 value')

local task_15 = mod.by_id['1-5']
assert(task_15, 'expected 1-5 task to exist')
assert(task_15.target_count == 1, 'expected 1-5 target_count to match')
assert(task_15.spawn_unit_id == 400001, 'expected 1-5 boss task to use the explicit boss unit mapping')
assert(task_15.spawn_area_id == 'challenge_spawn_mid', 'expected 1-5 boss task to use the explicit mainline spawn area')
assert(task_15.is_boss_task == true, 'expected 1-5 to be marked as a boss task')
assert(task_15.reward_lines[1].key == 'physical_damage_pct', 'expected 1-5 reward line 1 key')
assert(task_15.reward_lines[2].key == 'magic_damage_pct', 'expected 1-5 reward line 2 key')
assert(task_15.reward_lines[3].value == 100, 'expected 1-5 reward line 3 value')

local task_110 = mod.by_id['1-10']
assert(task_110, 'expected 1-10 task to exist')
assert(task_110.reward_lines[1].key == 'wood', 'expected 1-10 wood reward key')
assert(task_110.reward_lines[1].value == 100, 'expected 1-10 wood reward value')
assert(task_110.reward_lines[2].type == 'special', 'expected 1-10 special reward type')
assert(task_110.reward_lines[2].key == 'treasure_choice', 'expected 1-10 special reward key')
assert(task_110.reward_lines[2].value == 1, 'expected 1-10 special reward value')

local task_21 = mod.by_id['2-1']
assert(task_21, 'expected 2-1 task to exist')
assert(task_21.reward_lines[1].key == 'gold', 'expected 2-1 gold reward key')
assert(task_21.reward_lines[1].value == 2000, 'expected 2-1 gold reward value')
assert(task_21.reward_lines[2].key == 'kill_count', 'expected 2-1 reward line 2 key')
assert(task_21.reward_lines[2].value == 300, 'expected 2-1 reward line 2 value')

local task_25 = mod.by_id['2-5']
local task_effects_25 = attreffect.by_source.mainline_task and attreffect.by_source.mainline_task['2-5']
assert(task_25, 'expected 2-5 task to exist')
assert(task_effects_25 ~= nil, 'expected 2-5 numeric task rows in attreffect')
assert(task_effects_25.attr['每秒金币'] == 10, 'expected canonical gold-per-sec key for 2-5 in attreffect')
assert(task_effects_25.attr['每秒杀敌'] == 1, 'expected canonical kill-per-sec key for 2-5 in attreffect')
assert(task_25.target_count == 1, 'expected 2-5 target_count to match')
assert(task_25.reward_lines[1].key == 'gold_per_sec', 'expected 2-5 reward line 1 key')
assert(task_25.reward_lines[2].key == 'kill_per_sec', 'expected 2-5 reward line 2 key')
assert(task_25.reward_lines[3].value == 100, 'expected 2-5 reward line 3 value')

local task_210 = mod.by_id['2-10']
assert(task_210, 'expected 2-10 task to exist')
assert(task_210.objective_text == '击杀古尔丹', 'expected 2-10 objective_text to match')
assert(task_210.reward_lines[2].type == 'special', 'expected 2-10 special reward type')
assert(task_210.reward_lines[2].key == 'treasure_choice', 'expected 2-10 special reward key')

local task_31 = mod.by_id['3-1']
assert(task_31, 'expected 3-1 task to exist')
assert(task_31.reward_lines[1].key == 'strength', 'expected 3-1 reward line 1 key')
assert(task_31.reward_lines[1].value == 50, 'expected 3-1 reward line 1 value')
assert(task_31.reward_lines[2].key == 'strength_growth_pct', 'expected 3-1 reward line 2 key')
assert(task_31.reward_lines[2].value == 3, 'expected 3-1 reward line 2 value')

local task_35 = mod.by_id['3-5']
local task_effects_35 = attreffect.by_source.mainline_task and attreffect.by_source.mainline_task['3-5']
assert(task_35, 'expected 3-5 task to exist')
assert(task_effects_35 ~= nil, 'expected 3-5 numeric task rows in attreffect')
assert(task_effects_35.state['skill_point'] == 1, 'expected canonical skill_point state for 3-5 in attreffect')
assert(task_35.target_count == 1, 'expected 3-5 target_count to match')
assert(task_35.is_boss_task == true, 'expected 3-5 to stay marked as a boss task')
assert(task_35.reward_lines[1].key == 'exp', 'expected 3-5 reward line 1 key')
assert(task_35.reward_lines[1].value == 1000, 'expected 3-5 reward line 1 value')
assert(task_35.reward_lines[3].type == 'special', 'expected 3-5 state row to be adapted back into special reward_lines')
assert(task_35.reward_lines[3].key == 'skill_point', 'expected 3-5 reward line 3 key')
assert(task_35.reward_lines[3].value == 1, 'expected 3-5 reward line 3 value')

local task_37 = mod.by_id['3-7']
assert(task_37, 'expected 3-7 task to exist')
assert(task_37.reward_lines[1].key == 'strength_per_sec', 'expected 3-7 reward line 1 key')
assert(task_37.reward_lines[1].value == 0.1, 'expected 3-7 reward line 1 value')
assert(task_37.reward_lines[2].key == 'elite_damage_pct', 'expected 3-7 reward line 2 key')
assert(task_37.reward_lines[2].value == 5, 'expected 3-7 reward line 2 value')

local task_310 = mod.by_id['3-10']
assert(task_310, 'expected 3-10 task to exist')
assert(task_310.reward_lines[1].key == 'wood', 'expected 3-10 wood reward key')
assert(task_310.reward_lines[1].value == 100, 'expected 3-10 wood reward value')
assert(task_310.reward_lines[2].type == 'special', 'expected 3-10 special reward type')
assert(task_310.reward_lines[2].key == 'hero_card', 'expected 3-10 special reward key')
assert(task_310.reward_lines[2].value == 1, 'expected 3-10 special reward value')

local task_41 = mod.by_id['4-1']
assert(task_41, 'expected 4-1 task to exist')
assert(task_41.reward_lines[1].key == 'metal_damage_pct', 'expected 4-1 reward line 1 key')
assert(task_41.reward_lines[1].value == 10, 'expected 4-1 reward line 1 value')
assert(task_41.reward_lines[2].key == 'wood', 'expected 4-1 reward line 2 key')
assert(task_41.reward_lines[2].value == 50, 'expected 4-1 reward line 2 value')

local task_42 = mod.by_id['4-2']
assert(task_42, 'expected 4-2 task to exist')
assert(task_42.reward_lines[1].key == 'fire_damage_pct', 'expected 4-2 reward line 1 key')
assert(task_42.reward_lines[2].key == 'water_damage_pct', 'expected 4-2 reward line 2 key')

local task_43 = mod.by_id['4-3']
assert(task_43, 'expected 4-3 task to exist')
assert(task_43.reward_lines[1].key == 'wood_damage_pct', 'expected 4-3 reward line 1 key')
assert(task_43.reward_lines[1].value == 10, 'expected 4-3 reward line 1 value')
assert(task_43.reward_lines[2].key == 'wood', 'expected 4-3 reward line 2 key')

local task_45 = mod.by_id['4-5']
assert(task_45, 'expected 4-5 task to exist')
assert(task_45.target_count == 1, 'expected 4-5 target_count to match')
assert(task_45.spawn_unit_id == 400007, 'expected 4-5 boss task to use the explicit boss unit mapping')
assert(task_45.reward_lines[1].key == 'wood_per_sec', 'expected 4-5 reward line 1 key')
assert(task_45.reward_lines[1].value == 0.1, 'expected 4-5 reward line 1 value')
assert(task_45.reward_lines[2].key == 'gold_per_sec', 'expected 4-5 reward line 2 key')
assert(task_45.reward_lines[3].key == 'exp_per_sec', 'expected 4-5 reward line 3 key')

local task_410 = mod.by_id['4-10']
assert(task_410, 'expected 4-10 task to exist')
assert(task_410.reward_lines[1].key == 'wood', 'expected 4-10 wood reward key')
assert(task_410.reward_lines[2].key == 'treasure_choice', 'expected 4-10 reward line 2 key')
assert(task_410.reward_lines[3].key == 'skill_point', 'expected 4-10 reward line 3 key')

print('[OK] mainline task rewards csv loader smoke passed')
