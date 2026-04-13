local M = {}

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
  strength_per_sec = '每秒力量',
  agility_per_sec = '每秒敏捷',
  intelligence_per_sec = '每秒智力',
  kill_gold_pct = '杀敌金币',
  kill_exp_pct = '杀敌经验',
  kill_wood_pct = '杀敌木材',
  basic_attack_damage_pct = '普攻伤害',
  skill_damage_pct = '技能伤害',
  all_damage_pct = '所有伤害',
  elite_damage_pct = '精控伤害',
  boss_damage_pct = '挑战伤害',
  challenge_damage_pct = '挑战伤害',
}

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

  local api = {}

  local function get_task_catalog()
    return CONFIG.mainline_task_rewards and CONFIG.mainline_task_rewards.by_id or {}
  end

  local function ensure_runtime()
    STATE.mainline_task_runtime = STATE.mainline_task_runtime or {
      chapter_id = 1,
      floor_index = 1,
      completed_task_ids = {},
      hero_card_count = 0,
    }
    return STATE.mainline_task_runtime
  end

  local function is_challenge_mode()
    return STATE.current_mode_def and STATE.current_mode_def.mode_id == 'challenge'
  end

  local function get_floor_index()
    local runtime = ensure_runtime()
    local wave_index = math.max(STATE.current_wave_index or 0, STATE.started_wave_count or 0, runtime.floor_index or 1)
    return math.max(1, wave_index)
  end

  function api.get_current_task_id()
    if not is_challenge_mode() then
      return nil
    end
    local runtime = ensure_runtime()
    local chapter_id = math.max(1, tonumber(runtime.chapter_id) or 1)
    local floor_index = get_floor_index()
    runtime.floor_index = floor_index
    return string.format('%d-%d', chapter_id, floor_index)
  end

  function api.get_current_task()
    local task_id = api.get_current_task_id()
    if not task_id then
      return nil
    end
    return get_task_catalog()[task_id]
  end

  local function build_reward_line_text(line)
    if not line then
      return nil
    end
    local value = line.value
    local raw_number = tonumber(line.value) or 0
    if round_number and math.abs(raw_number % 1) <= 0.0001 then
      value = round_number(raw_number)
    end
    local value_text = tostring(value)
    if raw_number >= 0 then
      value_text = '+' .. value_text
    end
    return string.format('%s %s', tostring(line.key or '?'), value_text)
  end

  function api.get_current_task_summary()
    local task = api.get_current_task()
    if not task then
      return nil
    end
    return {
      id = task.id,
      title_text = task.title_text,
      objective_text = task.objective_text,
      progress_text = string.format('(0/%d)', task.target_count or 0),
      reward_lines = clone_list(task.reward_lines),
      reward_line_texts = (function()
        local lines = {}
        for _, line in ipairs(task.reward_lines or {}) do
          lines[#lines + 1] = build_reward_line_text(line)
        end
        return lines
      end)(),
    }
  end

  function api.handle_task_cleared(task)
    task = task or api.get_current_task()
    if not task or not task.id then
      return false
    end

    local runtime = ensure_runtime()
    if runtime.completed_task_ids[task.id] then
      return false
    end

    api.apply_task_rewards(task)
    if message then
      message(string.format('%s 完成。', task.title_text or task.id))
    end
    return true
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
    end
    return true
  end

  return api
end

return M
