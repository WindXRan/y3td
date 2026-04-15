package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local MainlineTaskRuntime = require 'runtime.mainline_tasks'

local state = {
  current_wave_index = 2,
  started_wave_count = 2,
  current_mode_def = { mode_id = 'challenge' },
  hero = {},
}

local rewards = {}
local treasures = 0

local api = MainlineTaskRuntime.create({
  STATE = state,
  CONFIG = {
    mainline_task_rewards = require 'data.object_tables.mainline_task_rewards',
  },
  round_number = function(value)
    return math.floor((value or 0) + 0.5)
  end,
  message = function() end,
  add_hero_attr_pack = function(_, pack)
    rewards.attr = pack
  end,
  award_rewards = function(reward)
    rewards.resource = reward
  end,
  queue_treasure_round = function()
    treasures = treasures + 1
  end,
})

local current = api.get_current_task()
assert(current ~= nil, 'expected current mainline task in challenge mode')
assert(current.id == '1-2', 'expected challenge mode current task to map to chapter 1 floor 2 by default')

local summary = api.get_current_task_summary()
assert(summary.title_text == '主线1-2', 'expected summary title')
assert(summary.progress_text == '(0/3)', 'expected summary progress text')
assert(type(summary.reward_lines) == 'table' and #summary.reward_lines == 3, 'expected reward lines')

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
