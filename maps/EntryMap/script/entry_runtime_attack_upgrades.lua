local M = {}

function M.create(env)
  local STATE = env.STATE
  local message = env.message
  local get_attack_skill = env.get_attack_skill
  local get_empty_attack_skill_slot = env.get_empty_attack_skill_slot
  local get_unlocked_attack_skill_count = env.get_unlocked_attack_skill_count
  local get_upgrade_pick_count = env.get_upgrade_pick_count
  local record_upgrade_pick = env.record_upgrade_pick
  local unlock_attack_skill = env.unlock_attack_skill
  local sync_basic_attack_ability = env.sync_basic_attack_ability
  local build_attack_skill_slot_text = env.build_attack_skill_slot_text

  local ATTACK_UPGRADE_DEFS = {
    {
      key = 'unlock_arcane_arrow',
      tag = '新技能',
      skill_id = 'arcane_arrow',
      name = '奥术箭',
      desc = '装配到空余攻击技能位，冷却 2.0 秒，造成 80% 攻击的能量魔法伤害。',
      weight = 10,
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('arcane_arrow')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('arcane_arrow')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    },
    {
      key = 'unlock_flame_arrow',
      tag = '新技能',
      skill_id = 'flame_arrow',
      name = '爆炎箭',
      desc = '装配到空余攻击技能位，冷却 6.2 秒，命中并爆炸造成火系物理伤害。',
      weight = 10,
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('flame_arrow')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('flame_arrow')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    },
    {
      key = 'unlock_frost_arrow',
      tag = '新技能',
      skill_id = 'frost_arrow',
      name = '寒冰箭',
      desc = '装配到空余攻击技能位，冷却 4.8 秒，造成冰系魔法伤害。',
      weight = 10,
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('frost_arrow')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('frost_arrow')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    },
    {
      key = 'unlock_thunder',
      tag = '新技能',
      skill_id = 'thunder',
      name = '天雷',
      desc = '装配到空余攻击技能位，冷却 5.5 秒，召唤天雷打击目标。',
      weight = 10,
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('thunder')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('thunder')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    },
    {
      key = 'basic_attack_damage',
      tag = '普攻',
      skill_id = 'basic_attack',
      level_delta = 1,
      name = '强化箭矢',
      desc = '普攻伤害 +20%。',
      weight = 5,
      max_picks = 5,
      can_offer = function()
        return get_attack_skill('basic_attack') ~= nil
      end,
      apply = function(state)
        local skill = get_attack_skill('basic_attack')
        skill.damage_ratio = skill.damage_ratio + 0.20
        state.skill_runtime.normal_attack_bonus_ratio = state.skill_runtime.normal_attack_bonus_ratio + 0.20
        sync_basic_attack_ability()
      end,
    },
    {
      key = 'basic_attack_speed',
      tag = '普攻',
      skill_id = 'basic_attack',
      level_delta = 1,
      name = '迅捷拉弦',
      desc = '攻击速度 +15%。',
      weight = 4,
      max_picks = 3,
      can_offer = function()
        return get_attack_skill('basic_attack') ~= nil
      end,
      apply = function(state)
        local skill = get_attack_skill('basic_attack')
        skill.attack_speed_bonus = skill.attack_speed_bonus + 15
        state.hero:add_attr('攻击速度', 15)
        sync_basic_attack_ability()
      end,
    },
    {
      key = 'basic_attack_range',
      tag = '普攻',
      skill_id = 'basic_attack',
      level_delta = 1,
      name = '猎手视界',
      desc = '攻击范围 +80。',
      weight = 3,
      max_picks = 2,
      can_offer = function()
        return get_attack_skill('basic_attack') ~= nil
      end,
      apply = function(state)
        local skill = get_attack_skill('basic_attack')
        skill.range_bonus = skill.range_bonus + 80
        state.hero:add_attr('攻击范围', 80)
        sync_basic_attack_ability()
      end,
    },
    {
      key = 'arcane_damage',
      tag = '奥术箭',
      skill_id = 'arcane_arrow',
      level_delta = 1,
      name = '箭矢增幅',
      desc = '奥术箭伤害 +25%。',
      weight = 7,
      max_picks = 5,
      can_offer = function()
        return get_attack_skill('arcane_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('arcane_arrow')
        skill.damage_ratio = skill.damage_ratio + 0.25
      end,
    },
    {
      key = 'arcane_cdr',
      tag = '奥术箭',
      skill_id = 'arcane_arrow',
      level_delta = 1,
      name = '急速抽箭',
      desc = '奥术箭冷却缩减 12%。',
      weight = 5,
      max_picks = 4,
      can_offer = function()
        return get_attack_skill('arcane_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('arcane_arrow')
        skill.cooldown_reduction = math.min(0.60, skill.cooldown_reduction + 0.12)
      end,
    },
    {
      key = 'arcane_pierce',
      tag = '奥术箭',
      skill_id = 'arcane_arrow',
      level_delta = 1,
      name = '贯通延伸',
      desc = '奥术箭额外穿透 +1。',
      weight = 4,
      max_picks = 2,
      can_offer = function()
        return get_attack_skill('arcane_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('arcane_arrow')
        skill.pierce = skill.pierce + 1
      end,
    },
    {
      key = 'flame_damage',
      tag = '爆炎箭',
      skill_id = 'flame_arrow',
      level_delta = 1,
      name = '火箭增幅',
      desc = '爆炎箭命中与爆炸伤害 +20%。',
      weight = 7,
      max_picks = 5,
      can_offer = function()
        return get_attack_skill('flame_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('flame_arrow')
        skill.damage_ratio = skill.damage_ratio + 0.20
        skill.explosion_ratio = skill.explosion_ratio + 0.20
      end,
    },
    {
      key = 'flame_radius',
      tag = '爆炎箭',
      skill_id = 'flame_arrow',
      level_delta = 1,
      name = '爆炸扩散',
      desc = '爆炎箭爆炸范围 +60。',
      weight = 5,
      max_picks = 3,
      can_offer = function()
        return get_attack_skill('flame_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('flame_arrow')
        skill.explosion_radius = skill.explosion_radius + 60
      end,
    },
    {
      key = 'flame_repeat',
      tag = '爆炎箭',
      skill_id = 'flame_arrow',
      level_delta = 1,
      name = '连珠火箭',
      desc = '爆炎箭额外释放 1 次。',
      weight = 4,
      max_picks = 2,
      can_offer = function()
        return get_attack_skill('flame_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('flame_arrow')
        skill.repeat_count = skill.repeat_count + 1
      end,
    },
    {
      key = 'frost_damage',
      tag = '寒冰箭',
      skill_id = 'frost_arrow',
      level_delta = 1,
      name = '冰箭增幅',
      desc = '寒冰箭伤害 +25%。',
      weight = 7,
      max_picks = 5,
      can_offer = function()
        return get_attack_skill('frost_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('frost_arrow')
        skill.damage_ratio = skill.damage_ratio + 0.25
      end,
    },
    {
      key = 'frost_cdr',
      tag = '寒冰箭',
      skill_id = 'frost_arrow',
      level_delta = 1,
      name = '冰箭连发',
      desc = '寒冰箭冷却缩减 10%。',
      weight = 5,
      max_picks = 4,
      can_offer = function()
        return get_attack_skill('frost_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('frost_arrow')
        skill.cooldown_reduction = math.min(0.55, skill.cooldown_reduction + 0.10)
      end,
    },
    {
      key = 'frost_pierce',
      tag = '寒冰箭',
      skill_id = 'frost_arrow',
      level_delta = 1,
      name = '冰箭贯穿',
      desc = '寒冰箭额外穿透 +1。',
      weight = 4,
      max_picks = 2,
      can_offer = function()
        return get_attack_skill('frost_arrow') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('frost_arrow')
        skill.pierce = skill.pierce + 1
      end,
    },
    {
      key = 'thunder_damage',
      tag = '天雷',
      skill_id = 'thunder',
      level_delta = 1,
      name = '雷击增幅',
      desc = '天雷伤害 +25%。',
      weight = 7,
      max_picks = 5,
      can_offer = function()
        return get_attack_skill('thunder') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('thunder')
        skill.damage_ratio = skill.damage_ratio + 0.25
      end,
    },
    {
      key = 'thunder_chain',
      tag = '天雷',
      skill_id = 'thunder',
      level_delta = 1,
      name = '连续雷击',
      desc = '天雷额外打击 1 个附近目标。',
      weight = 6,
      max_picks = 3,
      can_offer = function()
        return get_attack_skill('thunder') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('thunder')
        skill.extra_targets = skill.extra_targets + 1
      end,
    },
    {
      key = 'thunder_cdr',
      tag = '天雷',
      skill_id = 'thunder',
      level_delta = 1,
      name = '高压导体',
      desc = '天雷冷却缩减 10%。',
      weight = 5,
      max_picks = 4,
      can_offer = function()
        return get_attack_skill('thunder') ~= nil
      end,
      apply = function()
        local skill = get_attack_skill('thunder')
        skill.cooldown_reduction = math.min(0.55, skill.cooldown_reduction + 0.10)
      end,
    },
  }
  
  local function is_unlock_upgrade(upgrade)
    return upgrade and type(upgrade.key) == 'string' and string.sub(upgrade.key, 1, 7) == 'unlock_'
  end
  
  local function get_upgrade_balance_wave_index()
    return math.max(1, STATE.current_wave_index or 0, STATE.started_wave_count or 0)
  end
  
  local function get_unlock_offer_chance(unlocked_skill_count)
    local wave_index = get_upgrade_balance_wave_index()
    if unlocked_skill_count <= 1 then
      if wave_index <= 1 then
        return 0.75
      end
      if wave_index == 2 then
        return 0.65
      end
      return 0.50
    end
    if unlocked_skill_count == 2 then
      if wave_index <= 1 then
        return 0.55
      end
      if wave_index == 2 then
        return 0.45
      end
      return 0.35
    end
    if unlocked_skill_count == 3 then
      if wave_index <= 2 then
        return 0.30
      end
      if wave_index <= 4 then
        return 0.22
      end
      return 0.15
    end
    return 0
  end
  
  local function get_skill_regular_upgrade_pick_count(skill_id)
    if not skill_id then
      return 0
    end
  
    local total = 0
    for _, upgrade in ipairs(ATTACK_UPGRADE_DEFS) do
      if upgrade.skill_id == skill_id and not is_unlock_upgrade(upgrade) then
        total = total + get_upgrade_pick_count(upgrade.key)
      end
    end
    return total
  end
  
  local function get_regular_upgrade_weight(upgrade)
    local base_weight = upgrade.weight or 1
    local skill_id = upgrade.skill_id
    if not skill_id then
      return base_weight
    end
  
    local factor = 1.0
    local wave_index = get_upgrade_balance_wave_index()
    local picked_count = get_skill_regular_upgrade_pick_count(skill_id)
  
    if picked_count > 0 then
      factor = factor * 1.25
    else
      factor = factor * 0.90
    end
  
    if skill_id == 'basic_attack' then
      if wave_index <= 2 then
        factor = factor * 1.20
      elseif picked_count >= 2 then
        factor = factor * 0.85
      end
    end
  
    if STATE.attack_skill_state and STATE.attack_skill_state.last_picked_skill_id == skill_id then
      factor = factor * 1.25
    end
  
    local feed_rounds = STATE.attack_skill_state
      and STATE.attack_skill_state.new_skill_feed
      and STATE.attack_skill_state.new_skill_feed[skill_id]
      or 0
    if feed_rounds > 0 then
      factor = factor * 1.60
    end
  
    factor = math.min(factor, 2.2)
    return base_weight * factor
  end
  
  local function get_upgrade_effective_weight(upgrade)
    if is_unlock_upgrade(upgrade) then
      return upgrade.weight or 1
    end
    return get_regular_upgrade_weight(upgrade)
  end
  
  local function count_distinct_skill_ids(pool)
    local seen = {}
    local count = 0
    for _, upgrade in ipairs(pool) do
      local skill_id = upgrade.skill_id
      if skill_id and not seen[skill_id] then
        seen[skill_id] = true
        count = count + 1
      end
    end
    return count
  end
  
  local function decay_new_skill_feed_rounds()
    if not STATE.attack_skill_state or not STATE.attack_skill_state.new_skill_feed then
      return
    end
  
    for skill_id, rounds in pairs(STATE.attack_skill_state.new_skill_feed) do
      local next_rounds = rounds - 1
      if next_rounds > 0 then
        STATE.attack_skill_state.new_skill_feed[skill_id] = next_rounds
      else
        STATE.attack_skill_state.new_skill_feed[skill_id] = nil
      end
    end
  end
  
  local function pick_weighted_upgrade(pool, avoid_skill_id)
    if #pool == 0 then
      return nil
    end
  
    local total_weight = 0
    local candidates = {}
    for index, upgrade in ipairs(pool) do
      if not avoid_skill_id or upgrade.skill_id ~= avoid_skill_id then
        local weight = math.max(0.01, get_upgrade_effective_weight(upgrade))
        total_weight = total_weight + weight
        candidates[#candidates + 1] = {
          index = index,
          weight = weight,
        }
      end
    end
  
    if #candidates == 0 then
      return pick_weighted_upgrade(pool, nil)
    end
  
    local roll = math.random() * total_weight
    local cumulative = 0
    local picked_index = candidates[#candidates].index
    for _, candidate in ipairs(candidates) do
      cumulative = cumulative + candidate.weight
      if roll <= cumulative then
        picked_index = candidate.index
        break
      end
    end
  
    local picked = pool[picked_index]
    table.remove(pool, picked_index)
    return picked
  end
  
  local function build_upgrade_pool()
    local regular_pool = {}
    local unlock_pool = {}
    for _, upgrade in ipairs(ATTACK_UPGRADE_DEFS) do
      local max_picks = upgrade.max_picks
      if (not max_picks or get_upgrade_pick_count(upgrade.key) < max_picks)
        and (not upgrade.can_offer or upgrade.can_offer(STATE)) then
        if is_unlock_upgrade(upgrade) then
          unlock_pool[#unlock_pool + 1] = upgrade
        else
          regular_pool[#regular_pool + 1] = upgrade
        end
      end
    end
    return regular_pool, unlock_pool
  end
  
  local function pick_upgrade_choices(count)
    local regular_pool, unlock_pool = build_upgrade_pool()
    local choices = {}
    local unlocked_skill_count = get_unlocked_attack_skill_count()
    local has_unlock_available = get_empty_attack_skill_slot() ~= nil and #unlock_pool > 0
    local unlock_added = false
  
    if has_unlock_available then
      local force_unlock = STATE.attack_skill_state
        and (STATE.attack_skill_state.unlock_offer_fail_streak or 0) >= 3
      local should_offer_unlock = force_unlock
        or math.random() <= get_unlock_offer_chance(unlocked_skill_count)
      if should_offer_unlock then
        local picked = pick_weighted_upgrade(unlock_pool)
        if picked then
          choices[#choices + 1] = picked
          unlock_added = true
        end
      end
    end
  
    local regular_skill_ids = {}
    while #choices < count and #regular_pool > 0 do
      local avoid_skill_id = nil
      if #regular_skill_ids == 1 and count_distinct_skill_ids(regular_pool) > 1 then
        avoid_skill_id = regular_skill_ids[1]
      end
  
      local picked = pick_weighted_upgrade(regular_pool, avoid_skill_id)
      if not picked then
        break
      end
      choices[#choices + 1] = picked
      regular_skill_ids[#regular_skill_ids + 1] = picked.skill_id
    end
  
    if #choices < count and not unlock_added and has_unlock_available then
      local picked = pick_weighted_upgrade(unlock_pool)
      if picked then
        choices[#choices + 1] = picked
        unlock_added = true
      end
    end
  
    while #choices < count and #regular_pool > 0 do
      local picked = pick_weighted_upgrade(regular_pool)
      if not picked then
        break
      end
      choices[#choices + 1] = picked
    end
  
    if STATE.attack_skill_state and #choices > 0 then
      if has_unlock_available then
        if unlock_added then
          STATE.attack_skill_state.unlock_offer_fail_streak = 0
        else
          STATE.attack_skill_state.unlock_offer_fail_streak =
            (STATE.attack_skill_state.unlock_offer_fail_streak or 0) + 1
        end
      else
        STATE.attack_skill_state.unlock_offer_fail_streak = 0
      end
  
      decay_new_skill_feed_rounds()
    end
  
    return choices
  end
  
  local function show_upgrade_choices()
    if STATE.game_finished then
      return
    end
  
    if STATE.awaiting_upgrade and STATE.current_upgrade_choices then
      message('继续当前 G 三选一。')
    else
      if STATE.skill_points <= 0 then
        message('技能点不足。')
        return
      end
  
      local choices = pick_upgrade_choices(3)
      if #choices == 0 then
        message('当前没有可用的攻击技能强化选项。')
        return
      end
  
      STATE.skill_points = STATE.skill_points - 1
      STATE.awaiting_upgrade = true
      STATE.current_upgrade_choices = choices
      message('攻击技能强化 3 选 1：按 1 / 2 / 3 选择。')
    end
  
    for index, upgrade in ipairs(STATE.current_upgrade_choices) do
      message(string.format('%d. [%s] %s %s', index, upgrade.tag or '强化', upgrade.name, upgrade.desc))
    end
  end
  
  local function apply_upgrade(index)
    if not STATE.awaiting_upgrade then
      return
    end
  
    local upgrade = STATE.current_upgrade_choices and STATE.current_upgrade_choices[index]
    if not upgrade then
      return
    end
  
    if upgrade.level_delta and upgrade.skill_id then
      local skill = get_attack_skill(upgrade.skill_id)
      if skill then
        skill.level = skill.level + upgrade.level_delta
      end
    end
  
    upgrade.apply(STATE)
    record_upgrade_pick(upgrade.key)
    if STATE.attack_skill_state then
      STATE.attack_skill_state.last_picked_skill_id = upgrade.skill_id
    end
    STATE.awaiting_upgrade = false
    STATE.current_upgrade_choices = nil
    message('已选择强化：' .. upgrade.name)
  
    if upgrade.skill_id == 'basic_attack' then
      sync_basic_attack_ability()
    end
  
    if upgrade.skill_id and get_attack_skill(upgrade.skill_id) then
      local skill = get_attack_skill(upgrade.skill_id)
      message('技能更新：' .. build_attack_skill_slot_text(skill.slot))
    end
  end

  return {
    show_upgrade_choices = show_upgrade_choices,
    apply_upgrade = apply_upgrade,
  }
end

return M