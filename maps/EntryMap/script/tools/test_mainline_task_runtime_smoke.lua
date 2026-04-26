package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local MainlineTaskRuntime = require 'runtime.mainline_tasks'

local state = {
  current_wave_index = 2,
  started_wave_count = 2,
  runtime_elapsed = 0,
  current_mode_def = { mode_id = 'challenge' },
  mainline_task_runtime = {
    active_task_id = '1-2',
    state = 'idle',
    chain_exhausted = false,
    completed_task_ids = {},
    rewarded_task_ids = {},
    hero_card_count = 0,
    progress_by_task_id = {},
    auto_track_enabled = true,
    pinned_task_id = nil,
    snapshot_summary = nil,
    last_result = 'none',
    last_result_reason = nil,
    active_challenge = nil,
  },
  hero = {},
}

local rewards = {}
local treasures = 0
local messages = {}
local started_instances = {}

local api = MainlineTaskRuntime.create({
  STATE = state,
  CONFIG = {
    mainline_task_rewards = require 'data.object_tables.mainline_task_rewards',
  },
  round_number = function(value)
    return math.floor((value or 0) + 0.5)
  end,
  message = function(text)
    messages[#messages + 1] = tostring(text)
  end,
  add_hero_attr_pack = function(_, pack)
    rewards.attr = pack
  end,
  award_rewards = function(reward)
    rewards.resource = reward
  end,
  queue_treasure_round = function()
    treasures = treasures + 1
  end,
  start_mainline_task_challenge = function(task)
    local instance = {
      id = 'mainline_task:' .. tostring(task.id),
      mainline_task_id = task.id,
      active = true,
    }
    started_instances[#started_instances + 1] = instance
    return instance
  end,
})

local current = api.get_current_task()
assert(current ~= nil, 'expected current mainline task in challenge mode')
assert(current.id == '1-2', 'expected current task to come from mainline runtime state instead of stage selection')

local idle_summary = api.get_current_task_summary()
assert(idle_summary.id == '1-2', 'expected idle summary to point at current task')
assert(idle_summary.state == 'idle', 'expected current task to start idle before explicit challenge start')
assert(idle_summary.can_start == true, 'expected current task to be startable while idle')
assert(idle_summary.progress_text == '按 C 开启当前层挑战', 'expected idle summary to guide the player to start the task')
assert(idle_summary.timer_text == '限时 60 秒', 'expected idle summary to expose the default time limit')
assert(idle_summary.reward_line_texts[1] == '格挡 +2', 'expected reward line formatting to stay intact')

assert(api.handle_enemy_killed({ kind = 'main', wave = { index = 2 } }) == false, 'expected kills not to count before the task challenge starts')
assert(api.get_current_progress_count('1-2') == 0, 'expected idle task progress to stay at zero before explicit start')

local tracker = api.get_tracker_state()
assert(tracker.auto_track_enabled == true, 'expected tracker auto tracking enabled by default')
assert(tracker.state == 'idle', 'expected tracker state to mirror the task runtime state')
assert(tracker.can_start == true, 'expected tracker to expose the start action while idle')

local started, start_reason = api.start_current_task_challenge()
assert(started == true and start_reason == nil, 'expected start_current_task_challenge to enter the running state')

local running_summary = api.get_current_task_summary()
assert(running_summary.state == 'running', 'expected running summary after explicit start')
assert(running_summary.can_start == false, 'expected running tasks not to be re-openable')
assert(running_summary.progress_text == '击杀虚空行者(0/3)', 'expected running summary to render kill progress')
assert(running_summary.timer_text == '剩余 60 秒', 'expected running summary to show the full remaining timer at start')
assert(started_instances[#started_instances].mainline_task_id == '1-2', 'expected start_current_task_challenge to request a battlefield challenge instance for the current task')
assert(api.start_current_task_challenge() == false, 'expected duplicate starts to be rejected while running')

assert(api.handle_enemy_killed({ kind = 'main', wave = { index = 1 } }) == false, 'expected non-challenge kills not to advance running progress')
assert(api.handle_enemy_killed({ kind = 'challenge', owner = { id = 'mainline_task:1-1', mainline_task_id = '1-1' } }) == false, 'expected kills from other mainline task instances not to advance progress')
assert(api.handle_enemy_killed({ kind = 'challenge', owner = started_instances[#started_instances] }) == true, 'expected matching challenge kills to advance the active task challenge')
assert(api.handle_enemy_killed({ kind = 'challenge', owner = started_instances[#started_instances] }) == true, 'expected matching challenge kills to keep advancing the active task challenge')

local in_progress = api.get_current_task_summary()
assert(in_progress.current_count == 2, 'expected matching kills to advance current task progress')
assert(in_progress.progress_text == '击杀虚空行者(2/3)', 'expected running progress text to reflect updated kill count')
assert(in_progress.timer_text == '剩余 60 秒', 'expected progress updates not to mutate the timer text before ticking')

api.handle_challenge_finished(started_instances[#started_instances], false)

local failed_summary = api.get_current_task_summary()
assert(failed_summary.state == 'idle', 'expected timeout to send the task back to idle')
assert(failed_summary.can_start == true, 'expected timed out tasks to be startable again through the same start action')
assert(failed_summary.progress_text == '本层挑战失败，可再次开启', 'expected failed idle summary to explain the retry flow')
assert(failed_summary.timer_text == '请重新开始当前层挑战', 'expected failed idle timer text to explain the retry flow')
assert(api.get_current_progress_count('1-2') == 0, 'expected timeout cleanup to clear the failed task progress')

local failed_tracker = api.get_tracker_state()
assert(failed_tracker.state == 'idle', 'expected tracker state to return to idle after timeout')
assert(failed_tracker.last_result == 'failed', 'expected tracker to preserve the latest failed result')
assert(failed_tracker.last_result_reason == 'timeout', 'expected tracker to record timeout failures')

local restarted = api.start_current_task_challenge()
assert(restarted == true, 'expected the same start action to reopen the failed task')

assert(api.handle_enemy_killed({ kind = 'challenge', owner = started_instances[#started_instances] }) == true, 'expected restarted tasks to count kills again')
assert(api.handle_enemy_killed({ kind = 'challenge', owner = started_instances[#started_instances] }) == true, 'expected restarted tasks to count kills again')
assert(api.handle_enemy_killed({ kind = 'challenge', owner = started_instances[#started_instances] }) == true, 'expected restarted tasks to record the final kill before the challenge success callback')
api.handle_challenge_finished(started_instances[#started_instances], true)

local completed = api.get_current_task_summary()
assert(rewards.attr['格挡'] == 2, 'expected current task attr reward line 1 to be granted once at completion')
assert(rewards.attr['护甲'] == 2, 'expected current task attr reward line 2 to be granted once at completion')
assert(rewards.resource.wood == 50, 'expected current task reward wood to be granted once at completion')
assert(messages[#messages - 1] == '第二层 已完成。', 'expected mainline completion text to be emitted when reaching the task target')
assert(messages[#messages] == '第二层 奖励已发放。', 'expected mainline reward grant text to be emitted once after rewards are applied')
assert(api.is_task_completed('1-2') == true, 'expected task to be marked completed after reaching target')
assert(api.is_task_rewarded('1-2') == true, 'expected task reward state to persist after completion')
assert(completed.id == '1-3', 'expected runtime to hand off to the next task after the current task completes')
assert(completed.state == 'idle', 'expected the next task to return to idle after handoff')
assert(completed.can_start == true, 'expected the next task to be startable immediately after handoff')
assert(completed.progress_text == '按 C 开启当前层挑战', 'expected the next task summary to wait for an explicit start')

state.mainline_task_runtime.active_task_id = '1-5'
state.mainline_task_runtime.last_result = 'none'
state.mainline_task_runtime.last_result_reason = nil
state.mainline_task_runtime.state = 'idle'
state.mainline_task_runtime.active_challenge = nil
local percent_summary = api.get_current_task_summary()
assert(percent_summary.reward_line_texts[1] == '物理伤害 +3%', 'expected pct rewards to render with a percent sign')
assert(percent_summary.reward_line_texts[2] == '魔法伤害 +3%', 'expected secondary pct rewards to render with a percent sign')

state.mainline_task_runtime.active_task_id = '4-10'
state.mainline_task_runtime.last_result = 'none'
state.mainline_task_runtime.last_result_reason = nil
state.mainline_task_runtime.state = 'idle'
state.mainline_task_runtime.active_challenge = nil
local mixed_reward_summary = api.get_current_task_summary()
assert(mixed_reward_summary.reward_line_texts[1] == '木材 +100', 'expected resource rewards to render with readable localized text')
assert(mixed_reward_summary.reward_line_texts[2] == '获得 1 次宝物', 'expected treasure choice rewards to render with readable acquisition text')
assert(#mixed_reward_summary.reward_line_texts == 2, 'expected 4-10 to render two reward lines')

state.mainline_task_runtime.active_task_id = '3-10'
state.mainline_task_runtime.last_result = 'none'
state.mainline_task_runtime.last_result_reason = nil
state.mainline_task_runtime.state = 'idle'
state.mainline_task_runtime.active_challenge = nil
local hero_card_summary = api.get_current_task_summary()
assert(hero_card_summary.reward_line_texts[2] == '英雄卡 +1', 'expected hero card rewards to render with readable localized text')

local final_task_api = MainlineTaskRuntime.create({
  STATE = {
    current_wave_index = 5,
    started_wave_count = 5,
    runtime_elapsed = 0,
    current_mode_def = { mode_id = 'challenge' },
    mainline_task_runtime = {
      active_task_id = '4-10',
      state = 'idle',
      chain_exhausted = false,
      completed_task_ids = {},
      rewarded_task_ids = {},
      hero_card_count = 0,
      progress_by_task_id = {},
      auto_track_enabled = true,
      pinned_task_id = nil,
      snapshot_summary = nil,
      last_result = 'none',
      last_result_reason = nil,
      active_challenge = nil,
    },
    hero = {},
  },
  CONFIG = {
    mainline_task_rewards = require 'data.object_tables.mainline_task_rewards',
  },
  round_number = function(value)
    return math.floor((value or 0) + 0.5)
  end,
  message = function() end,
  add_hero_attr_pack = function() end,
  award_rewards = function() end,
  queue_treasure_round = function() end,
  start_mainline_task_challenge = function(task)
    return {
      id = 'mainline_task:' .. tostring(task.id),
      mainline_task_id = task.id,
      active = true,
    }
  end,
})

assert(final_task_api.start_current_task_challenge() == true, 'expected final task to start through the same action')
local final_instance = { id = 'mainline_task:4-10', mainline_task_id = '4-10' }
assert(final_task_api.handle_enemy_killed({ kind = 'challenge', owner = final_instance }) == true, 'expected final boss task to record the matching kill')
final_task_api.handle_challenge_finished(final_instance, true)
assert(final_task_api.is_task_completed('4-10') == true, 'expected final boss task to complete')
assert(final_task_api.get_current_task() == nil, 'expected task chain to stay exhausted after the final mainline task completes')

api.apply_task_rewards({
  reward_lines = {
    { type = 'attr', key = 'hp', value = 100 },
    { type = 'resource', key = 'wood', value = 50 },
    { type = 'special', key = 'treasure_choice', value = 1 },
  }
})

assert(rewards.attr['生命'] == 100, 'expected attr reward to map to hero attr pack')
assert(rewards.resource.wood == 50, 'expected resource reward to map to reward pack')
assert(treasures == 1, 'expected treasure special reward to queue treasure round')

print('[OK] mainline task runtime smoke passed')
