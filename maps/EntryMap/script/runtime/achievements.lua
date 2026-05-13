local CsvLoader = require 'data.csv_loader'

local M = {}

local achievements = {}
local player_progress = {}
local listeners = {}
local trigger_handlers = {}

local function load_achievements()
  local rows = CsvLoader.read_rows('data_csv/by_feature/economy/shangchengdaojv.csv')
  local achievement_id = 1
  for _, row in ipairs(rows) do
    if row.partition == '生涯' and row.tab1 == '成就' and row.trigger_type then
      local id = string.format('ach_%03d', achievement_id)
      achievements[id] = {
        id = id,
        name = row.name,
        description = row.special_effect,
        trigger_type = row.trigger_type,
        trigger_param1 = tonumber(row.trigger_param) or row.trigger_param,
        trigger_param2 = nil,
        unlock_reward = row.attr,
        display_icon = tonumber(row.icon),
        category = row.tab2_a or 'general',
        progress_key = row.trigger_type .. '_' .. (row.trigger_param or '0'),
        unlocked = false,
        quality = row.quality,
      }
      achievement_id = achievement_id + 1
    end
  end
end

local function notify_listeners(event_type, achievement, progress, is_unlocked)
  for _, listener in ipairs(listeners) do
    if listener[event_type] then
      listener[event_type](achievement, progress, is_unlocked)
    end
  end
end

local function check_achievement(achievement_id, current_value)
  local achievement = achievements[achievement_id]
  if not achievement or achievement.unlocked then
    return
  end

  local target = achievement.trigger_param1
  local is_numeric = type(target) == 'number'
  local is_unlocked = false

  if is_numeric then
    is_unlocked = current_value >= target
  else
    local param = achievement.trigger_param1
    local difficulty_tag = current_value
    if param == difficulty_tag or 
       (param == 'N' and string.sub(difficulty_tag, 1, 1) == 'N') or
       (param == 'R' and string.sub(difficulty_tag, 1, 1) == 'R') then
      is_unlocked = true
    end
  end

  local progress = is_numeric and math.min(current_value, target) or 1

  if is_unlocked then
    achievement.unlocked = true
    player_progress[achievement_id] = {
      current = current_value,
      target = target,
      unlocked = true,
      unlocked_at = os.time(),
    }
    notify_listeners('achievement_unlocked', achievement, progress, true)
  else
    player_progress[achievement_id] = {
      current = current_value,
      target = target,
      unlocked = false,
    }
    notify_listeners('progress_updated', achievement, progress, false)
  end
end

local function register_trigger_handler(trigger_type, handler)
  trigger_handlers[trigger_type] = trigger_handlers[trigger_type] or {}
  table.insert(trigger_handlers[trigger_type], handler)
end

local function trigger_event(trigger_type, value)
  local handlers = trigger_handlers[trigger_type]
  if not handlers then
    return
  end
  for _, handler in ipairs(handlers) do
    handler(value)
  end
end

local function setup_trigger_handlers()
  register_trigger_handler('kill_count', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'kill_count' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('elite_kill_count', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'elite_kill_count' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('boss_kill_count', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'boss_kill_count' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('battle_win', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'battle_win' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('battle_win_streak', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'battle_win_streak' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('stage_complete', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'stage_complete' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('stage_difficulty_complete', function(difficulty_tag)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'stage_difficulty_complete' and not achievement.unlocked then
        check_achievement(achievement.id, difficulty_tag)
      end
    end
  end)

  register_trigger_handler('hero_max_level_count', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'hero_max_level_count' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('gold_earned', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'gold_earned' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('wood_earned', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'wood_earned' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('skill_unlocked_count', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'skill_unlocked_count' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('bond_activated_count', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'bond_activated_count' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)

  register_trigger_handler('battle_survival_time', function(value)
    for _, achievement in pairs(achievements) do
      if achievement.trigger_type == 'battle_survival_time' and not achievement.unlocked then
        check_achievement(achievement.id, value)
      end
    end
  end)
end

function M.init()
  load_achievements()
  setup_trigger_handlers()
end

function M.trigger(trigger_type, value)
  trigger_event(trigger_type, value)
end

function M.get_achievement(achievement_id)
  return achievements[achievement_id]
end

function M.get_all_achievements()
  return achievements
end

function M.get_progress(achievement_id)
  return player_progress[achievement_id]
end

function M.get_all_progress()
  return player_progress
end

function M.get_unlocked_count()
  local count = 0
  for _, achievement in pairs(achievements) do
    if achievement.unlocked then
      count = count + 1
    end
  end
  return count
end

function M.register_listener(listener)
  listeners[#listeners + 1] = listener
end

function M.unregister_listener(listener)
  for i = #listeners, 1, -1 do
    if listeners[i] == listener then
      table.remove(listeners, i)
      break
    end
  end
end

function M.get_trigger_types()
  local types = {}
  for type_name in pairs(trigger_handlers) do
    types[#types + 1] = type_name
  end
  return types
end

return M