local M = {}

local DEFAULT_MAINLINE_WAVE_SPAN = 5
local DEFAULT_TASK_TIME_LIMIT = 60

local ATTR_KEY_MAP = {
  hp = '生命',
  hp_regen = '生命恢复',
  armor = '护甲',
  block = '格挡',
  attack = '攻击',
  attack_range = '攻击范围',
  attack_speed_pct = '攻击速度',
  strength = '力量',
  agility = '敏捷',
  intelligence = '智力',
  all_attributes = '全属性',
  strength_growth_pct = '力量增幅',
  agility_growth_pct = '敏捷增幅',
  intelligence_growth_pct = '智力增幅',
  attack_growth_pct = '攻击增幅',
  physical_damage_pct = '物理伤害',
  magic_damage_pct = '魔法伤害',
  basic_attack_damage_pct = '普攻伤害',
  skill_damage_pct = '技能伤害',
  all_damage_pct = '所有伤害',
  physical_crit_pct = '物理暴击',
  physical_crit_damage_pct = '物理暴伤',
  magic_crit_pct = '魔法暴击',
  magic_crit_damage_pct = '魔法暴伤',
  metal_damage_pct = '金行伤害',
  wood_damage_pct = '木行伤害',
  water_damage_pct = '水行伤害',
  fire_damage_pct = '火行伤害',
  earth_damage_pct = '土行伤害',
}

local RUNTIME_ATTR_KEY_MAP = {
  gold_per_sec = '每秒金币',
  wood_per_sec = '每秒木材',
  exp_per_sec = '每秒经验',
  kill_count = '杀敌数',
  kill_per_sec = '每秒杀敌',
  strength_per_sec = '每秒力量',
  agility_per_sec = '每秒敏捷',
  intelligence_per_sec = '每秒智力',
  kill_gold_pct = '杀敌金币',
  kill_exp_pct = '杀敌经验',
  kill_wood_pct = '杀敌木材',
  kill_material_pct = '杀敌木材',
  basic_attack_damage_pct = '普攻伤害',
  skill_damage_pct = '技能伤害',
  all_damage_pct = '所有伤害',
  elite_damage_pct = '精控伤害',
  boss_damage_pct = '挑战伤害',
  challenge_damage_pct = '挑战伤害',
}

local RESOURCE_KEY_MAP = {
  gold = '金币',
  wood = '木材',
  exp = '经验',
}

local CHINESE_DIGITS = {
  [0] = '零',
  [1] = '一',
  [2] = '二',
  [3] = '三',
  [4] = '四',
  [5] = '五',
  [6] = '六',
  [7] = '七',
  [8] = '八',
  [9] = '九',
}

local function to_chinese_number(value)
  local number = math.max(0, math.floor(tonumber(value) or 0))
  if number <= 10 then
    if number == 10 then
      return '十'
    end
    return CHINESE_DIGITS[number] or tostring(number)
  end
  if number < 20 then
    return '十' .. (CHINESE_DIGITS[number % 10] or '')
  end
  if number < 100 then
    local tens = math.floor(number / 10)
    local ones = number % 10
    local text = (CHINESE_DIGITS[tens] or tostring(tens)) .. '十'
    if ones > 0 then
      text = text .. (CHINESE_DIGITS[ones] or tostring(ones))
    end
    return text
  end
  return tostring(number)
end

local function get_floor_index_from_task(task)
  if not task then
    return nil
  end
  local chapter = tonumber(task.chapter_id)
  local order_index = tonumber(task.order_index)
  if chapter and order_index and chapter > 0 and order_index > 0 then
    return (chapter - 1) * 10 + order_index
  end
  local chapter_text, floor_text = tostring(task.id or ''):match('^(%d+)%-(%d+)$')
  if chapter_text and floor_text then
    return (tonumber(chapter_text) - 1) * 10 + tonumber(floor_text)
  end
  return nil
end

local function get_floor_label(task)
  local floor_index = get_floor_index_from_task(task)
  if not floor_index or floor_index <= 0 then
    return nil
  end
  return string.format('第%s层', to_chinese_number(floor_index))
end

local function clone_list(list)
  local result = {}
  for index, value in ipairs(list or {}) do
    result[index] = value
  end
  return result
end

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local round_number = env.round_number
  local message = env.message
  local add_hero_attr_pack = env.add_hero_attr_pack
  local award_rewards = env.award_rewards
  local queue_treasure_round = env.queue_treasure_round
  local start_mainline_task_challenge = env.start_mainline_task_challenge

  local api = {}

  local function get_task_catalog()
    return CONFIG.mainline_task_rewards and CONFIG.mainline_task_rewards.by_id or {}
  end

  local function get_task_list()
    return CONFIG.mainline_task_rewards and CONFIG.mainline_task_rewards.list or {}
  end

  local function find_task_index(task_id)
    if not task_id then
      return nil
    end
    for index, task in ipairs(get_task_list()) do
      if task and task.id == task_id then
        return index
      end
    end
    return nil
  end

  local function get_first_task()
    return get_task_list()[1]
  end

  local function get_next_task(task_id)
    local current_index = find_task_index(task_id)
    if not current_index then
      return nil
    end
    return get_task_list()[current_index + 1]
  end

  local function get_mainline_wave_span()
    if type(CONFIG.waves) == 'table' and #CONFIG.waves > 0 then
      return #CONFIG.waves
    end
    return DEFAULT_MAINLINE_WAVE_SPAN
  end

  local function ensure_runtime()
    STATE.mainline_task_runtime = STATE.mainline_task_runtime or {
      active_task_id = nil,
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
    }

    local runtime = STATE.mainline_task_runtime
    runtime.state = runtime.state or 'idle'
    runtime.completed_task_ids = runtime.completed_task_ids or {}
    runtime.rewarded_task_ids = runtime.rewarded_task_ids or {}
    runtime.progress_by_task_id = runtime.progress_by_task_id or {}
    runtime.auto_track_enabled = runtime.auto_track_enabled ~= false
    runtime.last_result = runtime.last_result or 'none'
    runtime.last_result_reason = runtime.last_result_reason
    runtime.active_challenge = runtime.active_challenge

    return runtime
  end

  local function seed_current_task_if_needed(runtime)
    if runtime.active_task_id ~= nil or runtime.chain_exhausted == true then
      return
    end

    local first_task = get_first_task()
    if first_task then
      runtime.active_task_id = first_task.id
      runtime.state = runtime.state or 'idle'
      return
    end

    runtime.chain_exhausted = true
    runtime.state = 'exhausted'
  end

  local function is_battle_mode()
    if STATE.session_phase ~= nil then
      return STATE.session_phase == 'battle'
    end
    return STATE.current_mode_def ~= nil
  end

  local function get_task_target_wave_index(task)
    if not task then
      return nil
    end
    local order_index = tonumber(task.order_index)
    if not order_index or order_index <= 0 then
      local _, floor_text = tostring(task.id or ''):match('^(%d+)%-(%d+)$')
      order_index = tonumber(floor_text)
    end
    if not order_index or order_index <= 0 then
      return nil
    end
    local wave_span = math.max(1, tonumber(get_mainline_wave_span()) or DEFAULT_MAINLINE_WAVE_SPAN)
    return ((order_index - 1) % wave_span) + 1
  end

  local function round_reward_value(raw_number)
    local value = raw_number
    if round_number and math.abs(raw_number % 1) <= 0.0001 then
      value = round_number(raw_number)
    end
    return value
  end

  local function format_signed_reward_value(raw_number, is_percent)
    local value = round_reward_value(raw_number)
    local value_text = tostring(value)
    if raw_number >= 0 then
      value_text = '+' .. value_text
    end
    if is_percent then
      value_text = value_text .. '%'
    end
    return value_text
  end

  local function build_reward_line_text(line)
    if not line then
      return nil
    end
    local raw_number = tonumber(line.value) or 0

    if line.type == 'resource' then
      local display_key = RESOURCE_KEY_MAP[line.key] or tostring(line.key or '?')
      return string.format('%s %s', display_key, format_signed_reward_value(raw_number, false))
    end

    if line.type == 'special' then
      local value = round_reward_value(raw_number)
      if line.key == 'treasure_choice' then
        return string.format('获得 %s 次宝物', tostring(value))
      end
      if line.key == 'skill_point' then
        return string.format('技能点 %s', format_signed_reward_value(raw_number, false))
      end
      if line.key == 'hero_card' then
        return string.format('英雄卡 %s', format_signed_reward_value(raw_number, false))
      end
    end

    local display_key = ATTR_KEY_MAP[line.key] or RUNTIME_ATTR_KEY_MAP[line.key] or tostring(line.key or '?')
    return string.format(
      '%s %s',
      display_key,
      format_signed_reward_value(raw_number, tostring(line.key or ''):match('_pct$') ~= nil)
    )
  end

  local function build_reward_line_texts(task)
    local lines = {}
    for _, line in ipairs(task and task.reward_lines or {}) do
      lines[#lines + 1] = build_reward_line_text(line)
    end
    return lines
  end

  local function clear_active_challenge_runtime(runtime)
    runtime.active_challenge = nil
  end

  local function get_task_time_limit(task)
    local value = tonumber(task and task.time_limit)
    if value and value > 0 then
      return value
    end
    return DEFAULT_TASK_TIME_LIMIT
  end

  function api.get_current_task_id()
    if not is_battle_mode() then
      return nil
    end
    local runtime = ensure_runtime()
    seed_current_task_if_needed(runtime)
    if runtime.chain_exhausted then
      return nil
    end
    return runtime.active_task_id
  end

  function api.get_current_task()
    local task_id = api.get_current_task_id()
    if not task_id then
      return nil
    end
    return get_task_catalog()[task_id]
  end

  function api.get_current_progress_count(task_id)
    local runtime = ensure_runtime()
    local progress_by_task_id = runtime.progress_by_task_id or {}
    return tonumber(progress_by_task_id[task_id or api.get_current_task_id()] or 0) or 0
  end

  function api.is_task_completed(task_id)
    local runtime = ensure_runtime()
    return runtime.completed_task_ids[task_id] == true
  end

  function api.is_task_rewarded(task_id)
    local runtime = ensure_runtime()
    return runtime.rewarded_task_ids[task_id] == true
  end

  function api.sync_current_task()
    if not is_battle_mode() then
      return nil
    end
    local runtime = ensure_runtime()
    seed_current_task_if_needed(runtime)
    return api.get_current_task()
  end

  function api.handle_wave_started()
    return api.sync_current_task()
  end

  local function apply_attr_reward(line, attr_pack)
    local key = ATTR_KEY_MAP[line.key]
    if not key then
      return false
    end
    attr_pack[key] = (attr_pack[key] or 0) + (tonumber(line.value) or 0)
    return true
  end

  local function apply_runtime_reward(line, attr_pack)
    local key = RUNTIME_ATTR_KEY_MAP[line.key]
    if not key then
      return false
    end
    attr_pack[key] = (attr_pack[key] or 0) + (tonumber(line.value) or 0)
    return true
  end

  function api.apply_task_rewards(task)
    task = task or api.get_current_task()
    if not task then
      return false
    end

    local attr_pack = {}
    local reward_pack = { gold = 0, wood = 0, exp = 0 }
    local runtime = ensure_runtime()
    if task.id and runtime.rewarded_task_ids[task.id] then
      return false
    end

    for _, line in ipairs(task.reward_lines or {}) do
      if line.type == 'attr' then
        apply_attr_reward(line, attr_pack)
      elseif line.type == 'runtime' then
        apply_runtime_reward(line, attr_pack)
      elseif line.type == 'resource' then
        reward_pack[line.key] = (reward_pack[line.key] or 0) + (tonumber(line.value) or 0)
      elseif line.type == 'special' then
        if line.key == 'treasure_choice' and queue_treasure_round then
          for _ = 1, tonumber(line.value) or 0 do
            queue_treasure_round('mainline_task', task.title_text or task.id)
          end
        elseif line.key == 'skill_point' then
          STATE.skill_points = (STATE.skill_points or 0) + (tonumber(line.value) or 0)
        elseif line.key == 'hero_card' then
          runtime.hero_card_count = (runtime.hero_card_count or 0) + (tonumber(line.value) or 0)
          if message then
            message(string.format('%s：英雄卡 %+d。', task.title_text or task.id, tonumber(line.value) or 0))
          end
        end
      end
    end

    if next(attr_pack) and add_hero_attr_pack and STATE.hero then
      add_hero_attr_pack(STATE.hero, attr_pack)
    end
    if (reward_pack.gold or 0) ~= 0 or (reward_pack.wood or 0) ~= 0 or (reward_pack.exp or 0) ~= 0 then
      award_rewards(reward_pack, task.title_text or task.id, false)
    end

    if task.id then
      runtime.completed_task_ids[task.id] = true
      runtime.rewarded_task_ids[task.id] = true
    end
    if message then
      message(string.format('%s 奖励已发放。', task.title_text or task.id))
    end
    return true
  end

  function api.can_start_current_task()
    local runtime = ensure_runtime()
    seed_current_task_if_needed(runtime)
    if runtime.chain_exhausted or runtime.state == 'exhausted' then
      return false
    end
    if runtime.state == 'running' then
      return false
    end
    return api.get_current_task() ~= nil
  end

  function api.start_current_task_challenge()
    local runtime = ensure_runtime()
    seed_current_task_if_needed(runtime)
    if runtime.chain_exhausted or runtime.state == 'exhausted' then
      return false, 'all_tasks_completed'
    end
    if runtime.state == 'running' then
      return false, 'task_already_running'
    end

    local task = api.get_current_task()
    if not task then
      return false, 'task_not_found'
    end

    local instance = start_mainline_task_challenge and start_mainline_task_challenge(task) or nil
    if not instance then
      return false, 'challenge_start_failed'
    end

    runtime.progress_by_task_id[task.id] = 0
    runtime.active_challenge = {
      task_id = task.id,
      instance_id = instance.id,
      elapsed = 0,
      time_limit = get_task_time_limit(task),
      target_count = tonumber(task.target_count) or 0,
      kill_count = 0,
      alive_count = tonumber(task.target_count) or 0,
    }
    runtime.state = 'running'
    runtime.last_result = 'none'
    runtime.last_result_reason = nil
    return true
  end

  function api.fail_current_task(reason)
    local runtime = ensure_runtime()
    if runtime.state ~= 'running' then
      return false, 'task_not_running'
    end

    local task = api.get_current_task()
    if task and task.id then
      runtime.progress_by_task_id[task.id] = 0
    end
    clear_active_challenge_runtime(runtime)
    runtime.state = 'idle'
    runtime.last_result = 'failed'
    runtime.last_result_reason = reason or 'unknown'
    return true
  end

  function api.complete_current_task()
    local runtime = ensure_runtime()
    if runtime.state ~= 'running' then
      return false, 'task_not_running'
    end

    local task = api.get_current_task()
    local challenge = runtime.active_challenge
    if not task or not challenge then
      return false, 'missing_active_task'
    end
    if challenge.alive_count > 0 then
      return false, 'task_not_cleared'
    end

    runtime.state = 'completed'
    runtime.completed_task_ids[task.id] = true

    if message then
      message(string.format('%s 已完成。', task.title_text or task.id))
    end
    api.apply_task_rewards(task)

    clear_active_challenge_runtime(runtime)

    local next_task = get_next_task(task.id)
    if next_task then
      runtime.active_task_id = next_task.id
      runtime.state = 'idle'
      runtime.last_result = 'success'
      runtime.last_result_reason = nil
    else
      runtime.active_task_id = nil
      runtime.chain_exhausted = true
      runtime.state = 'exhausted'
      runtime.last_result = 'success'
      runtime.last_result_reason = nil
    end
    return true
  end

  function api.handle_enemy_killed(info)
    local runtime = ensure_runtime()
    if runtime.state ~= 'running' then
      return false
    end

    local task = api.get_current_task()
    local challenge = runtime.active_challenge
    if not task or not challenge then
      return false
    end
    if challenge.task_id ~= task.id then
      return false
    end
    if type(info) ~= 'table' or info.kind ~= 'challenge' then
      return false
    end
    local owner = info.owner
    if not owner or tostring(owner.id) ~= tostring(challenge.instance_id) then
      return false
    end

    local target_count = tonumber(task.target_count or challenge.target_count or 0) or 0
    challenge.kill_count = math.min(target_count, (challenge.kill_count or 0) + 1)
    challenge.alive_count = math.max(0, target_count - challenge.kill_count)
    runtime.progress_by_task_id[task.id] = challenge.kill_count
    return true
  end

  function api.update(dt)
    local runtime = ensure_runtime()
    if runtime.state ~= 'running' then
      return false
    end

    local challenge = runtime.active_challenge
    if not challenge then
      return false
    end
    challenge.elapsed = math.max(0, tonumber(challenge.elapsed) or 0) + (tonumber(dt) or 0)
    return false
  end

  function api.handle_challenge_finished(instance, is_success)
    local runtime = ensure_runtime()
    local challenge = runtime.active_challenge
    if not challenge or not instance then
      return false
    end
    if tostring(challenge.instance_id) ~= tostring(instance.id) then
      return false
    end
    if is_success == true then
      challenge.alive_count = 0
      challenge.kill_count = challenge.target_count or challenge.kill_count or 0
      runtime.progress_by_task_id[challenge.task_id] = challenge.kill_count
      return api.complete_current_task()
    end
    return api.fail_current_task('timeout')
  end

  function api.handle_wave_cleared()
    return false
  end

  function api.handle_task_cleared()
    return false
  end

  function api.get_current_task_summary()
    local runtime = ensure_runtime()
    seed_current_task_if_needed(runtime)
    local task = api.get_current_task()
    if not task then
      if runtime.chain_exhausted or runtime.state == 'exhausted' then
        return {
          id = nil,
          title_text = '爬塔挑战',
          objective_text = '已完成全部层数挑战',
          current_count = 0,
          target_count = 0,
          progress_text = '爬塔挑战全部完成',
          timer_text = '',
          reward_lines = {},
          reward_line_texts = {},
          state = 'exhausted',
          state_text = '全部完成',
          can_start = false,
          is_running = false,
          is_completed = true,
          is_failed = false,
        }
      end
      return nil
    end

    local challenge = runtime.active_challenge
    local current_count = api.get_current_progress_count(task.id)
    local target_count = tonumber(task.target_count) or 0
    local time_limit = get_task_time_limit(task)
    local state = runtime.state or 'idle'
    local progress_text
    local timer_text
    local state_text

    if state == 'running' and challenge then
      current_count = tonumber(challenge.kill_count or current_count) or 0
      local remain = math.max(0, math.ceil((challenge.time_limit or time_limit) - (challenge.elapsed or 0)))
      progress_text = string.format('%s(%d/%d)', task.objective_text or '任务', current_count, target_count)
      timer_text = string.format('剩余 %d 秒', remain)
      state_text = '挑战中'
    elseif state == 'exhausted' or runtime.chain_exhausted == true then
      progress_text = '爬塔挑战全部完成'
      timer_text = ''
      state_text = '全部完成'
      state = 'exhausted'
    elseif runtime.last_result == 'failed' then
      progress_text = '本层挑战失败，可再次开启'
      timer_text = '请重新开始当前层挑战'
      state_text = '可挑战'
      current_count = 0
    else
      progress_text = '按 C 开启当前层挑战'
      timer_text = string.format('限时 %d 秒', time_limit)
      state_text = '可挑战'
      current_count = 0
    end

    return {
      id = task.id,
      chapter_text = get_floor_label(task) or ('第' .. tostring(task.id) .. '层'),
      title_text = task.title_text or get_floor_label(task),
      objective_text = task.objective_text,
      current_count = current_count,
      target_count = target_count,
      progress_text = progress_text,
      timer_text = timer_text,
      reward_lines = clone_list(task.reward_lines),
      reward_line_texts = build_reward_line_texts(task),
      state = state,
      state_text = state_text,
      can_start = api.can_start_current_task(),
      is_running = state == 'running',
      is_completed = runtime.completed_task_ids[task.id] == true,
      is_failed = runtime.last_result == 'failed',
      remaining_seconds = challenge and math.max(0, math.ceil((challenge.time_limit or time_limit) - (challenge.elapsed or 0))) or time_limit,
    }
  end

  function api.get_tracker_state()
    local runtime = ensure_runtime()
    local summary = api.get_current_task_summary()
    local tracker_summary = summary
    if runtime.auto_track_enabled == false and runtime.snapshot_summary then
      tracker_summary = runtime.snapshot_summary
    end
    return {
      auto_track_enabled = runtime.auto_track_enabled ~= false,
      pinned_task_id = runtime.pinned_task_id,
      snapshot_summary = runtime.snapshot_summary,
      state = tracker_summary and tracker_summary.state or runtime.state,
      can_start = tracker_summary and tracker_summary.can_start or false,
      last_result = runtime.last_result,
      last_result_reason = runtime.last_result_reason,
    }
  end

  function api.toggle_auto_track()
    local runtime = ensure_runtime()
    runtime.auto_track_enabled = not (runtime.auto_track_enabled ~= false)
    if runtime.auto_track_enabled then
      runtime.pinned_task_id = nil
      runtime.snapshot_summary = nil
    else
      local summary = api.get_current_task_summary()
      runtime.pinned_task_id = summary and summary.id or nil
      runtime.snapshot_summary = summary
    end
    return api.get_tracker_state()
  end

  return api
end

return M
