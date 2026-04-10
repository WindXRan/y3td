local TreasureObjects = require 'entry_objects.treasures'
local MarkObjects = require 'entry_objects.marks'
local MarkNodeObjects = require 'entry_objects.mark_nodes'

local M = {}

local TREASURE_QUALITY_LABELS = {
  common = '普通',
  rare = '稀有',
  epic = '史诗',
}

local MARK_QUALITY_LABELS = {
  common = '普通',
  rare = '稀有',
  epic = '史诗',
}

local TREASURE_DEF_LIST = TreasureObjects.list
local TREASURE_DEFS = TreasureObjects.by_id
local MARK_DEF_LIST = MarkObjects.list
local MARK_DEFS = MarkObjects.by_id
local MARK_NODES_BY_LEVEL = MarkNodeObjects.by_level

local function clone_reward(reward)
  if not reward then
    return nil
  end

  return {
    gold = reward.gold or 0,
    wood = reward.wood or 0,
    exp = reward.exp or 0,
    special = reward.special,
  }
end

local function add_bonus_pack(target, pack)
  if not target or not pack then
    return
  end

  for key, value in pairs(pack) do
    if value ~= nil and value ~= 0 then
      target[key] = (target[key] or 0) + value
    end
  end
end

local function is_high_quality_treasure(def)
  return def and (def.quality == 'rare' or def.quality == 'epic') or false
end

function M.create(env)
  local STATE = env.STATE
  local message = env.message
  local round_number = env.round_number
  local add_attr_pack = env.add_attr_pack
  local hero_attr_system = env.hero_attr_system
  local sync_basic_attack_ability = env.sync_basic_attack_ability
  local heal_hero = env.heal_hero
  local collect_bond_route_tags = env.collect_bond_route_tags

  local api = {
    TREASURE_DEFS = TREASURE_DEFS,
    MARK_DEFS = MARK_DEFS,
  }
  local resolve_treasure_pick

  function api.create_treasure_runtime()
    return {
      active_slots = {
        [1] = nil,
        [2] = nil,
        [3] = nil,
      },
      active_by_id = {},
      acquired_treasure_ids = {},
      discarded_treasure_ids = {},
      no_high_quality_rounds = 0,
      next_round_id = 1,
      current_round = nil,
      current_choices = nil,
      awaiting_choice = false,
      awaiting_replace = false,
      pending_replace_choice = nil,
      pending_bonus_refreshes = 0,
      temporary_buffs = {
        next_runtime_id = 1,
        active = {},
      },
      applied = {
        attr = {},
        runtime = {},
        skill_runtime = {},
        reward_ratio = {},
        passive_income = {},
        attack_skill = {},
      },
    }
  end

  function api.create_mark_runtime()
    return {
      owned_mark_ids = {},
      ordered_mark_ids = {},
      triggered_node_ids = {},
      rounds_by_id = {},
      next_round_id = 1,
      current_round = nil,
      current_choices = nil,
      awaiting_choice = false,
      applied = {
        attr = {},
        runtime = {},
        attack_skill = {},
      },
    }
  end

  function api.get_treasure_runtime()
    if not STATE.treasure_runtime then
      STATE.treasure_runtime = api.create_treasure_runtime()
    end
    return STATE.treasure_runtime
  end

  function api.get_mark_runtime()
    if not STATE.mark_runtime then
      STATE.mark_runtime = api.create_mark_runtime()
    end
    return STATE.mark_runtime
  end

  function api.get_reward_queue()
    if not STATE.reward_queue then
      STATE.reward_queue = {}
    end
    return STATE.reward_queue
  end

  function api.get_reward_queue_count()
    return #api.get_reward_queue()
  end

  function api.get_treasure_quality_label(quality)
    return TREASURE_QUALITY_LABELS[quality] or '普通'
  end

  function api.get_mark_quality_label(quality)
    return MARK_QUALITY_LABELS[quality] or '普通'
  end

  local function enqueue_reward_entry(entry)
    local queue = api.get_reward_queue()
    local priority = entry.priority or 0
    local insert_at = #queue + 1

    for index, queued in ipairs(queue) do
      if priority > (queued.priority or 0) then
        insert_at = index
        break
      end
    end

    table.insert(queue, insert_at, entry)
    return entry
  end

  function api.get_treasure_active_count()
    local runtime = api.get_treasure_runtime()
    local count = 0
    for slot = 1, 3, 1 do
      if runtime.active_slots[slot] then
        count = count + 1
      end
    end
    return count
  end

  local function get_empty_treasure_slot()
    local runtime = api.get_treasure_runtime()
    for slot = 1, 3, 1 do
      if not runtime.active_slots[slot] then
        return slot
      end
    end
    return nil
  end

  local function build_treasure_choice_text(index, def)
    return string.format(
      '%d. [%s] %s：%s',
      index,
      api.get_treasure_quality_label(def.quality),
      def.name,
      def.summary
    )
  end

  function api.build_treasure_slot_text(slot)
    local runtime = api.get_treasure_runtime()
    local treasure_id = runtime.active_slots[slot]
    if not treasure_id then
      return string.format('宝物位 %d：空。', slot)
    end

    local def = TREASURE_DEFS[treasure_id]
    if not def then
      return string.format('宝物位 %d：未知宝物 %s。', slot, tostring(treasure_id))
    end

    return string.format(
      '宝物位 %d：[%s] %s - %s',
      slot,
      api.get_treasure_quality_label(def.quality),
      def.name,
      def.summary
    )
  end

  function api.get_mark_active_count()
    local runtime = api.get_mark_runtime()
    return #runtime.ordered_mark_ids
  end

  local function build_mark_choice_text(index, def)
    return string.format(
      '%d. [%s] %s：%s',
      index,
      api.get_mark_quality_label(def.quality),
      def.name,
      def.summary
    )
  end

  function api.build_mark_slot_text(slot)
    local runtime = api.get_mark_runtime()
    local mark_id = runtime.ordered_mark_ids[slot]
    if not mark_id then
      return string.format('烙印位 %d：空。', slot)
    end

    local def = MARK_DEFS[mark_id]
    if not def then
      return string.format('烙印位 %d：未知烙印 %s。', slot, tostring(mark_id))
    end

    return string.format(
      '烙印位 %d：[%s] %s - %s',
      slot,
      api.get_mark_quality_label(def.quality),
      def.name,
      def.summary
    )
  end

  function api.show_mark_loadout()
    message('烙印栏：')
    local count = math.max(4, api.get_mark_active_count())
    for slot = 1, count, 1 do
      message(api.build_mark_slot_text(slot))
    end
  end

  local function build_current_treasure_tags()
    local tags = {
      basic_attack = true,
    }

    local attack_state = STATE.attack_skill_state
    if attack_state and attack_state.by_id then
      if attack_state.by_id.arcane_arrow
        or attack_state.by_id.flame_arrow
        or attack_state.by_id.frost_arrow
        or attack_state.by_id.thunder then
        tags.skill = true
        tags.spell_cycle = true
      end
      if attack_state.by_id.flame_arrow then
        tags.aoe = true
      end
      if attack_state.by_id.thunder then
        tags.bounce = true
      end
    end

    if STATE.skill_runtime and STATE.skill_runtime.splash_ratio > 0 then
      tags.aoe = true
    end
    if STATE.skill_runtime and STATE.skill_runtime.chain_bounces > 0 then
      tags.bounce = true
    end

    local runtime = api.get_treasure_runtime()
    if runtime.active_by_id.coin_casket or runtime.active_by_id.harvest_flask then
      tags.economy = true
    end
    if runtime.active_by_id.field_bandage
      or runtime.active_by_id.heart_guard_mirror
      or runtime.active_by_id.dragonblood_ring then
      tags.survival = true
    end

    if collect_bond_route_tags then
      for tag in pairs(collect_bond_route_tags() or {}) do
        tags[tag] = true
      end
    end

    return tags
  end

  local function get_treasure_quality_weights()
    local wave_index = math.max(STATE.current_wave_index or 0, STATE.started_wave_count or 0, 1)
    local weights

    if wave_index <= 2 then
      weights = { common = 72, rare = 24, epic = 4 }
    elseif wave_index <= 4 then
      weights = { common = 54, rare = 34, epic = 12 }
    else
      weights = { common = 38, rare = 40, epic = 22 }
    end

    local runtime = api.get_treasure_runtime()
    if runtime.no_high_quality_rounds >= 2 then
      weights.common = math.max(10, weights.common - 24)
      weights.rare = weights.rare + 18
      weights.epic = weights.epic + 6
    end

    return weights
  end

  local function build_available_treasure_defs(require_high_quality)
    local runtime = api.get_treasure_runtime()
    local result = {}

    for _, def in ipairs(TREASURE_DEF_LIST) do
      if not runtime.acquired_treasure_ids[def.id]
        and not runtime.discarded_treasure_ids[def.id]
        and not runtime.active_by_id[def.id]
        and (not require_high_quality or is_high_quality_treasure(def)) then
        result[#result + 1] = def
      end
    end

    return result
  end

  local function remove_treasure_def(list, treasure_id)
    for index, def in ipairs(list) do
      if def.id == treasure_id then
        table.remove(list, index)
        return
      end
    end
  end

  local function has_matching_tag(build_tags, candidate_tags)
    for _, tag in ipairs(candidate_tags or {}) do
      if build_tags[tag] then
        return true
      end
    end
    return false
  end

  local function get_treasure_pick_weight(def, build_tags, quality_weights)
    local weight = (def.pool_weight or 1) * (quality_weights[def.quality] or 1)

    if has_matching_tag(build_tags, def.best_with_tags) then
      weight = weight * 1.35
    elseif has_matching_tag(build_tags, def.theme_tags or def.tags) then
      weight = weight * 1.10
    end

    return math.max(0.01, weight)
  end

  local function pick_weighted_treasure(pool, build_tags, quality_weights)
    if #pool == 0 then
      return nil
    end

    local total_weight = 0
    local weights = {}
    for index, def in ipairs(pool) do
      local weight = get_treasure_pick_weight(def, build_tags, quality_weights)
      weights[index] = weight
      total_weight = total_weight + weight
    end

    if total_weight <= 0 then
      return pool[math.random(1, #pool)]
    end

    local roll = math.random() * total_weight
    local passed = 0
    for index, def in ipairs(pool) do
      passed = passed + weights[index]
      if roll <= passed then
        return def
      end
    end

    return pool[#pool]
  end

  function api.pick_treasure_choices(choice_count)
    local runtime = api.get_treasure_runtime()
    local available = build_available_treasure_defs(false)
    if #available == 0 then
      return {}
    end

    local build_tags = build_current_treasure_tags()
    local quality_weights = get_treasure_quality_weights()
    local choices = {}
    local guarantee_high_quality = runtime.no_high_quality_rounds >= 2

    if guarantee_high_quality then
      local high_quality_pool = build_available_treasure_defs(true)
      local guaranteed = pick_weighted_treasure(high_quality_pool, build_tags, quality_weights)
      if guaranteed then
        choices[#choices + 1] = guaranteed
        remove_treasure_def(available, guaranteed.id)
      end
    end

    while #choices < choice_count and #available > 0 do
      local picked = pick_weighted_treasure(available, build_tags, quality_weights)
      if not picked then
        break
      end
      choices[#choices + 1] = picked
      remove_treasure_def(available, picked.id)
    end

    local has_high_quality = false
    for _, def in ipairs(choices) do
      if is_high_quality_treasure(def) then
        has_high_quality = true
        break
      end
    end
    runtime.no_high_quality_rounds = has_high_quality and 0 or (runtime.no_high_quality_rounds + 1)

    return choices
  end

  local function build_available_mark_defs()
    local runtime = api.get_mark_runtime()
    local result = {}

    for _, def in ipairs(MARK_DEF_LIST) do
      if not runtime.owned_mark_ids[def.id] then
        result[#result + 1] = def
      end
    end

    return result
  end

  local function remove_mark_def(list, mark_id)
    for index, def in ipairs(list) do
      if def.id == mark_id then
        table.remove(list, index)
        return
      end
    end
  end

  local function get_mark_pick_weight(def)
    return math.max(0.01, def.pool_weight or 1)
  end

  local function pick_weighted_mark(pool)
    if #pool == 0 then
      return nil
    end

    local total_weight = 0
    local weights = {}
    for index, def in ipairs(pool) do
      local weight = get_mark_pick_weight(def)
      weights[index] = weight
      total_weight = total_weight + weight
    end

    if total_weight <= 0 then
      return pool[math.random(1, #pool)]
    end

    local roll = math.random() * total_weight
    local passed = 0
    for index, def in ipairs(pool) do
      passed = passed + weights[index]
      if roll <= passed then
        return def
      end
    end

    return pool[#pool]
  end

  local function pick_mark_choices(choice_count)
    local available = build_available_mark_defs()
    if #available == 0 then
      return {}
    end

    local choices = {}
    while #choices < choice_count and #available > 0 do
      local picked = pick_weighted_mark(available)
      if not picked then
        break
      end
      choices[#choices + 1] = picked
      remove_mark_def(available, picked.id)
    end

    return choices
  end

  function api.get_treasure_reward_ratio(key)
    local runtime = api.get_treasure_runtime()
    return runtime.applied.reward_ratio[key] or 0
  end

  function api.get_treasure_passive_income(key)
    local runtime = api.get_treasure_runtime()
    return runtime.applied.passive_income[key] or 0
  end

  function api.get_treasure_runtime_bonus(key)
    local runtime = api.get_treasure_runtime()
    return runtime.applied.runtime[key] or 0
  end

  function api.build_reward_with_treasure_bonus(reward)
    if not reward then
      return nil
    end

    local result = clone_reward(reward)
    local gold_ratio = api.get_treasure_reward_ratio('gold')
    local wood_ratio = api.get_treasure_reward_ratio('wood')
    local exp_ratio = api.get_treasure_reward_ratio('exp')

    if result.gold > 0 and gold_ratio > 0 then
      result.gold = result.gold + round_number(result.gold * gold_ratio)
    end
    if result.wood > 0 and wood_ratio > 0 then
      result.wood = result.wood + round_number(result.wood * wood_ratio)
    end
    if result.exp > 0 and exp_ratio > 0 then
      result.exp = result.exp + round_number(result.exp * exp_ratio)
    end

    return result
  end

  local function apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
    if not skill or not bonus then
      return
    end
    if not bonus.include_basic and skill_id == 'basic_attack' then
      return
    end

    local factor = direction or 1
    if bonus.cooldown_reduction and bonus.cooldown_reduction ~= 0 then
      skill.cooldown_reduction = math.max(0, (skill.cooldown_reduction or 0) + bonus.cooldown_reduction * factor)
    end
    if bonus.damage_ratio and bonus.damage_ratio ~= 0 then
      skill.damage_ratio = math.max(0, (skill.damage_ratio or 0) + bonus.damage_ratio * factor)
    end
    if bonus.repeat_count and bonus.repeat_count ~= 0 then
      skill.repeat_count = math.max(1, (skill.repeat_count or 1) + bonus.repeat_count * factor)
    end
    if bonus.range_bonus and bonus.range_bonus ~= 0 then
      skill.range_bonus = math.max(0, (skill.range_bonus or 0) + bonus.range_bonus * factor)
    end
  end

  api.apply_treasure_bonus_to_attack_skill = apply_treasure_bonus_to_attack_skill

  local function apply_treasure_attack_skill_bonus(bonus, direction)
    if not bonus or not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
      return
    end

    for skill_id, skill in pairs(STATE.attack_skill_state.by_id) do
      apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
    end
  end

  local function add_treasure_def_to_aggregate(aggregate, def)
    if not def or not def.bonuses then
      return
    end
    add_bonus_pack(aggregate.attr, def.bonuses.attr)
    add_bonus_pack(aggregate.runtime, def.bonuses.runtime)
    add_bonus_pack(aggregate.skill_runtime, def.bonuses.skill_runtime)
    add_bonus_pack(aggregate.reward_ratio, def.bonuses.reward_ratio)
    add_bonus_pack(aggregate.passive_income, def.bonuses.passive_income)
    add_bonus_pack(aggregate.attack_skill, def.bonuses.attack_skill)
  end

  local function grant_temporary_treasure(def, source_context)
    local runtime = api.get_treasure_runtime()
    local runtime_id = runtime.temporary_buffs.next_runtime_id
    runtime.temporary_buffs.next_runtime_id = runtime_id + 1

    local entry = {
      runtime_id = runtime_id,
      treasure_id = def.id,
      name = def.name,
      quality = def.quality,
      treasure_type = def.treasure_type,
      duration_type = def.duration_type,
      source_context = source_context,
      active = def.duration_type ~= 'next_boss' and def.duration_type ~= 'next_challenge',
      armed_for_boss = def.duration_type == 'next_boss',
      armed_for_challenge = def.duration_type == 'next_challenge',
      remaining_time = def.duration and (def.duration.duration_sec or def.duration.active_duration_sec) or nil,
      remaining_charges = def.duration and def.duration.max_charges or nil,
      guard_duration = def.duration and def.duration.guard_duration or nil,
      guard_remaining = 0,
      pending_bonus_refreshes = def.duration and def.duration.bonus_refreshes or 0,
      expires_on_wave = def.duration_type == 'wave' and STATE.current_wave_index or nil,
      challenge_instance_id = nil,
    }

    runtime.temporary_buffs.active[#runtime.temporary_buffs.active + 1] = entry
    runtime.acquired_treasure_ids[def.id] = true
    api.sync_treasure_effects()
    return entry
  end

  local function remove_expired_temporary_buffs(predicate)
    local runtime = api.get_treasure_runtime()
    local next_active = {}
    local removed = false
    for _, entry in ipairs(runtime.temporary_buffs.active) do
      if predicate(entry) then
        removed = true
      else
        next_active[#next_active + 1] = entry
      end
    end
    runtime.temporary_buffs.active = next_active
    if removed then
      api.sync_treasure_effects()
    end
    return removed
  end

  local function build_temporary_treasure_text(entry)
    if entry.duration_type == 'wave' then
      return string.format('[%s] %s：持续到本波结束。', api.get_treasure_quality_label(entry.quality), entry.name)
    end
    if entry.duration_type == 'timed' then
      return string.format('[%s] %s：剩余 %.0f 秒。', api.get_treasure_quality_label(entry.quality), entry.name, math.max(0, entry.remaining_time or 0))
    end
    if entry.duration_type == 'charges' then
      return string.format('[%s] %s：剩余 %d 次。', api.get_treasure_quality_label(entry.quality), entry.name, math.max(0, entry.remaining_charges or 0))
    end
    if entry.duration_type == 'next_boss' and entry.armed_for_boss then
      return string.format('[%s] %s：等待下一次 Boss 战触发。', api.get_treasure_quality_label(entry.quality), entry.name)
    end
    if entry.duration_type == 'next_challenge' and entry.armed_for_challenge then
      return string.format('[%s] %s：等待下一次挑战触发。', api.get_treasure_quality_label(entry.quality), entry.name)
    end
    return string.format('[%s] %s：生效中。', api.get_treasure_quality_label(entry.quality), entry.name)
  end

  local function build_treasure_bonus_pack()
    local runtime = api.get_treasure_runtime()
    local aggregate = {
      attr = {},
      runtime = {},
      skill_runtime = {},
      reward_ratio = {},
      passive_income = {},
      attack_skill = {},
    }
    local rare_count = 0
    local epic_count = 0

    for slot = 1, 3, 1 do
      local treasure_id = runtime.active_slots[slot]
      local def = treasure_id and TREASURE_DEFS[treasure_id] or nil
      if def then
        if def.quality == 'rare' then
          rare_count = rare_count + 1
        elseif def.quality == 'epic' then
          epic_count = epic_count + 1
        end
        add_treasure_def_to_aggregate(aggregate, def)
      end
    end

    for _, entry in ipairs(runtime.temporary_buffs.active or {}) do
      if entry.active and not entry.expired then
        local def = TREASURE_DEFS[entry.treasure_id]
        add_treasure_def_to_aggregate(aggregate, def)
        if entry.duration_type == 'charges' and (entry.guard_remaining or 0) > 0 then
          aggregate.attr['伤害减免'] = (aggregate.attr['伤害减免'] or 0) + 12
        end
      end
    end

    if runtime.active_by_id.crown_fragment then
      aggregate.attr['攻击'] = (aggregate.attr['攻击'] or 0) + rare_count * 12 + epic_count * 24
    end

    return aggregate
  end

  function api.sync_treasure_effects()
    local runtime = api.get_treasure_runtime()
    local previous = runtime.applied or {
      attr = {},
      runtime = {},
      skill_runtime = {},
      reward_ratio = {},
      passive_income = {},
      attack_skill = {},
    }

    if STATE.hero and STATE.hero:is_exist() then
      local negative_attr = {}
      for attr_name, value in pairs(previous.attr or {}) do
        if value ~= 0 then
          negative_attr[attr_name] = -value
        end
      end
      add_attr_pack(STATE.hero, negative_attr)
    end

    for key, value in pairs(previous.skill_runtime or {}) do
      if value ~= 0 then
        STATE.skill_runtime[key] = (STATE.skill_runtime[key] or 0) - value
      end
    end
    apply_treasure_attack_skill_bonus(previous.attack_skill or {}, -1)

    local aggregate = build_treasure_bonus_pack()

    if STATE.hero and STATE.hero:is_exist() then
      add_attr_pack(STATE.hero, aggregate.attr)
    end
    for key, value in pairs(aggregate.skill_runtime) do
      if value ~= 0 then
        STATE.skill_runtime[key] = (STATE.skill_runtime[key] or 0) + value
      end
    end
    apply_treasure_attack_skill_bonus(aggregate.attack_skill, 1)

    if (STATE.skill_runtime.medbot_every or 0) <= 0 then
      STATE.skill_runtime.medbot_kills = 0
    else
      STATE.skill_runtime.medbot_kills = math.min(
        STATE.skill_runtime.medbot_kills or 0,
        math.max(0, STATE.skill_runtime.medbot_every - 1)
      )
    end

    runtime.applied = aggregate
    sync_basic_attack_ability()
  end

  local function apply_mark_attack_skill_bonus(bonus, direction)
    if not bonus or not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
      return
    end

    local factor = direction or 1
    for skill_id, skill in pairs(STATE.attack_skill_state.by_id) do
      if skill_id ~= 'basic_attack' then
        apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, factor)
      end
    end
  end

  local function build_mark_bonus_pack()
    local runtime = api.get_mark_runtime()
    local aggregate = {
      attr = {},
      runtime = {},
      attack_skill = {},
    }

    for _, mark_id in ipairs(runtime.ordered_mark_ids) do
      local def = MARK_DEFS[mark_id]
      if def and def.bonuses then
        add_bonus_pack(aggregate.attr, def.bonuses.attr)
        add_bonus_pack(aggregate.runtime, def.bonuses.runtime)
        add_bonus_pack(aggregate.attack_skill, def.bonuses.attack_skill)
      end
    end

    return aggregate
  end

  function api.sync_mark_effects()
    local runtime = api.get_mark_runtime()
    local previous = runtime.applied or {
      attr = {},
      runtime = {},
      attack_skill = {},
    }

    if STATE.hero and STATE.hero:is_exist() then
      local negative_attr = {}
      for attr_name, value in pairs(previous.attr or {}) do
        if value ~= 0 then
          negative_attr[attr_name] = -value
        end
      end
      add_attr_pack(STATE.hero, negative_attr)
    end

    apply_mark_attack_skill_bonus(previous.attack_skill or {}, -1)

    local aggregate = build_mark_bonus_pack()

    if STATE.hero and STATE.hero:is_exist() then
      add_attr_pack(STATE.hero, aggregate.attr)
    end

    apply_mark_attack_skill_bonus(aggregate.attack_skill or {}, 1)

    runtime.applied = aggregate
    sync_basic_attack_ability()
  end

  function api.show_treasure_loadout()
    local runtime = api.get_treasure_runtime()
    message('宝物栏：')
    for slot = 1, 3, 1 do
      message(api.build_treasure_slot_text(slot))
    end
    message('临时宝物：')
    if #(runtime.temporary_buffs.active or {}) == 0 then
      message('暂无。')
    else
      for _, entry in ipairs(runtime.temporary_buffs.active) do
        message(build_temporary_treasure_text(entry))
      end
    end
  end

  local function try_process_reward_queue()
    if STATE.game_finished then
      return false
    end
    local mark_runtime = api.get_mark_runtime()
    if mark_runtime.awaiting_choice then
      return false
    end

    local runtime = api.get_treasure_runtime()
    if runtime.awaiting_choice or runtime.awaiting_replace then
      return false
    end
    if STATE.awaiting_upgrade then
      return false
    end
    if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice then
      return false
    end

    local queue = api.get_reward_queue()
    local next_entry = table.remove(queue, 1)
    if not next_entry then
      return false
    end

    if next_entry.kind == 'mark_choice' then
      local round = next_entry.round_id and mark_runtime.rounds_by_id[next_entry.round_id] or nil
      if not round then
        message('烙印轮次数据不存在，本次奖励已跳过。')
        return true
      end

      local choices = {}
      for _, mark_id in ipairs(round.candidate_mark_ids or {}) do
        local def = MARK_DEFS[mark_id]
        if def and not mark_runtime.owned_mark_ids[mark_id] then
          choices[#choices + 1] = def
        end
      end

      if #choices == 0 then
        message(string.format('%s：没有可用烙印候选，本轮已跳过。', round.ui_title or '烙印选择'))
        round.state = 'skipped'
        return true
      end

      mark_runtime.current_round = round
      mark_runtime.current_choices = choices
      mark_runtime.awaiting_choice = true
      round.state = 'pending'

      message(string.format('%s：获得一次烙印 3选1。', round.ui_title or '烙印选择'))
      api.show_mark_choices()
      return true
    end

    if next_entry.kind == 'treasure_choice' then
      local choices = api.pick_treasure_choices(3)
      if #choices == 0 then
        message('本局可用宝物已经抽空，本次不再生成新的宝物候选。')
        return true
      end

      runtime.current_round = {
        round_id = runtime.next_round_id,
        source_type = next_entry.source_type,
        source_name = next_entry.source_name,
        state = 'pending',
        free_refresh_left = 3 + (runtime.pending_bonus_refreshes or 0),
        refresh_paid_count = 0,
        candidate_treasure_ids = {},
      }
      runtime.pending_bonus_refreshes = 0
      runtime.next_round_id = runtime.next_round_id + 1
      runtime.current_choices = choices
      runtime.awaiting_choice = true
      runtime.awaiting_replace = false
      runtime.pending_replace_choice = nil
      STATE.choice_panel_hidden = false

      for _, def in ipairs(choices) do
        runtime.current_round.candidate_treasure_ids[#runtime.current_round.candidate_treasure_ids + 1] = def.id
      end

      message(string.format('%s 奖励：获得一次宝物 3选1。', next_entry.source_name or '宝物挑战'))
      api.show_treasure_choices()
      return true
    end

    message(string.format('存在未识别的奖励队列类型：%s。', tostring(next_entry.kind)))
    return true
  end

  resolve_treasure_pick = function(def, replace_slot)
    local runtime = api.get_treasure_runtime()
    local target_slot = replace_slot or get_empty_treasure_slot() or 1
    local replaced_id = runtime.active_slots[target_slot]

    if replaced_id then
      runtime.active_slots[target_slot] = nil
      runtime.active_by_id[replaced_id] = nil
      runtime.discarded_treasure_ids[replaced_id] = true
    end

    runtime.active_slots[target_slot] = def.id
    runtime.active_by_id[def.id] = {
      slot = target_slot,
      acquired_round_id = runtime.current_round and runtime.current_round.round_id or 0,
    }
    runtime.acquired_treasure_ids[def.id] = true

    runtime.awaiting_choice = false
    runtime.awaiting_replace = false
    runtime.current_choices = nil
    runtime.pending_replace_choice = nil
    runtime.current_round = nil

    api.sync_treasure_effects()

    message(string.format(
      '已获得宝物：[%s] %s。',
      api.get_treasure_quality_label(def.quality),
      def.name
    ))
    if replaced_id then
      local replaced_def = TREASURE_DEFS[replaced_id]
      if replaced_def then
        message(string.format('已替换宝物位 %d：%s。', target_slot, replaced_def.name))
      end
    end
    api.show_treasure_loadout()

    try_process_reward_queue()
  end

  function api.show_treasure_choices()
    local runtime = api.get_treasure_runtime()

    if runtime.awaiting_replace and runtime.pending_replace_choice then
      local def = runtime.pending_replace_choice
      message(string.format(
        '已选中 [%s] %s，请按 1 / 2 / 3 选择要替换的宝物位。',
        api.get_treasure_quality_label(def.quality),
        def.name
      ))
      for slot = 1, 3, 1 do
        message(string.format('%d. %s', slot, api.build_treasure_slot_text(slot)))
      end
      return
    end

    if not runtime.awaiting_choice or not runtime.current_choices then
      return
    end

    message('宝物 3选1：按 1 / 2 / 3 选择。')
    if api.get_treasure_active_count() >= 3 then
      message('当前 3 个宝物位已满，选中后还需要再指定一个被替换的旧宝物。')
    end
    for index, def in ipairs(runtime.current_choices) do
      message(build_treasure_choice_text(index, def))
    end
    api.show_treasure_loadout()
  end

  function api.apply_treasure_choice(index)
    local runtime = api.get_treasure_runtime()

    if runtime.awaiting_replace and runtime.pending_replace_choice then
      if not runtime.active_slots[index] then
        return
      end
      resolve_treasure_pick(runtime.pending_replace_choice, index)
      return
    end

    if not runtime.awaiting_choice or not runtime.current_choices then
      return
    end

    local def = runtime.current_choices[index]
    if not def then
      return
    end

    if def.treasure_type == 'tactical_temp' then
      runtime.awaiting_choice = false
      runtime.awaiting_replace = false
      runtime.current_choices = nil
      runtime.pending_replace_choice = nil
      runtime.current_round = nil
      local entry = grant_temporary_treasure(def, 'choice')
      message(string.format('已获得临时宝物：[%s] %s。', api.get_treasure_quality_label(def.quality), def.name))
      message(build_temporary_treasure_text(entry))
      try_process_reward_queue()
      return
    end

    local empty_slot = get_empty_treasure_slot()
    if empty_slot then
      resolve_treasure_pick(def, empty_slot)
      return
    end

    runtime.awaiting_choice = false
    runtime.awaiting_replace = true
    runtime.pending_replace_choice = def
    if runtime.current_round then
      runtime.current_round.state = 'await_replace'
      runtime.current_round.selected_treasure_id = def.id
    end
    api.show_treasure_choices()
  end

  local function resolve_mark_pick(def)
    local runtime = api.get_mark_runtime()
    runtime.owned_mark_ids[def.id] = true
    runtime.ordered_mark_ids[#runtime.ordered_mark_ids + 1] = def.id

    if runtime.current_round then
      runtime.current_round.selected_mark_id = def.id
      runtime.current_round.state = 'resolved'
    end

    runtime.awaiting_choice = false
    runtime.current_choices = nil
    runtime.current_round = nil

    api.sync_mark_effects()

    message(string.format(
      '已获得烙印：[%s] %s。',
      api.get_mark_quality_label(def.quality),
      def.name
    ))
    api.show_mark_loadout()

    try_process_reward_queue()
  end

  function api.show_mark_choices()
    local runtime = api.get_mark_runtime()
    if not runtime.awaiting_choice or not runtime.current_choices then
      return
    end

    local title = runtime.current_round and runtime.current_round.ui_title or '烙印选择'
    message(string.format('%s：按 1 / 2 / 3 选择。', title))
    for index, def in ipairs(runtime.current_choices) do
      message(build_mark_choice_text(index, def))
    end
    api.show_mark_loadout()
  end

  function api.apply_mark_choice(index)
    local runtime = api.get_mark_runtime()
    if not runtime.awaiting_choice or not runtime.current_choices then
      return
    end

    local def = runtime.current_choices[index]
    if not def then
      return
    end

    resolve_mark_pick(def)
  end

  function api.try_process_reward_queue()
    return try_process_reward_queue()
  end

  function api.update_temporary_treasures(dt)
    local runtime = api.get_treasure_runtime()
    local dirty = false
    for _, entry in ipairs(runtime.temporary_buffs.active) do
      if entry.active and entry.duration_type == 'timed' and entry.remaining_time then
        entry.remaining_time = math.max(0, entry.remaining_time - dt)
        if entry.remaining_time <= 0 then
          entry.expired = true
          dirty = true
        end
      end
      if entry.active and entry.duration_type == 'charges' and (entry.guard_remaining or 0) > 0 then
        entry.guard_remaining = math.max(0, entry.guard_remaining - dt)
        dirty = true
      end
    end
    if dirty then
      local removed = remove_expired_temporary_buffs(function(entry)
        return entry.expired == true
      end)
      if not removed then
        api.sync_treasure_effects()
      end
    end
  end

  function api.handle_wave_started(wave_index)
    remove_expired_temporary_buffs(function(entry)
      return entry.duration_type == 'wave'
        and entry.expires_on_wave ~= nil
        and entry.expires_on_wave < wave_index
    end)
  end

  function api.handle_boss_spawned()
    local runtime = api.get_treasure_runtime()
    for _, entry in ipairs(runtime.temporary_buffs.active) do
      if entry.armed_for_boss then
        entry.armed_for_boss = false
        entry.active = true
        entry.remaining_time = 60
      end
    end
    api.sync_treasure_effects()
  end

  function api.handle_challenge_started(instance)
    local runtime = api.get_treasure_runtime()
    for _, entry in ipairs(runtime.temporary_buffs.active) do
      if entry.armed_for_challenge then
        entry.armed_for_challenge = false
        entry.active = true
        entry.challenge_instance_id = instance.id
      end
    end
    api.sync_treasure_effects()
  end

  function api.handle_challenge_finished(instance, is_success)
    local runtime = api.get_treasure_runtime()
    for _, entry in ipairs(runtime.temporary_buffs.active) do
      if entry.duration_type == 'next_challenge' and entry.challenge_instance_id == instance.id then
        if is_success and (entry.pending_bonus_refreshes or 0) > 0 then
          runtime.pending_bonus_refreshes = runtime.pending_bonus_refreshes + entry.pending_bonus_refreshes
        end
        entry.expired = true
      end
    end
    remove_expired_temporary_buffs(function(entry)
      return entry.expired == true
    end)
  end

  function api.handle_hero_be_hurt()
    local runtime = api.get_treasure_runtime()
    local max_hp = 0
    local before_hp = STATE.hero and STATE.hero:is_exist() and STATE.hero:get_hp() or 0
    if STATE.hero and STATE.hero:is_exist() then
      max_hp = hero_attr_system and hero_attr_system.get_attr(STATE.hero, '生命结算值') or STATE.hero:get_attr('生命结算值') or 0
      if (tonumber(max_hp) or 0) <= 0 then
        max_hp = hero_attr_system and hero_attr_system.get_attr(STATE.hero, '生命') or STATE.hero:get_attr('生命') or STATE.hero:get_attr('最大生命') or 0
      end
    end
    for _, entry in ipairs(runtime.temporary_buffs.active) do
      if entry.duration_type == 'charges' and (entry.remaining_charges or 0) > 0 then
        entry.remaining_charges = entry.remaining_charges - 1
        if max_hp > 0 then
          if heal_hero then
            heal_hero(max_hp * 0.05)
          else
            STATE.hero:add_hp(max_hp * 0.05)
          end
        end
        entry.guard_remaining = entry.guard_duration or 0
        if entry.remaining_charges <= 0 then
          entry.expired = true
        end
      end
    end
    if hero_attr_system and STATE.hero and STATE.hero:is_exist() and hero_attr_system.log_snapshot then
      hero_attr_system.log_snapshot(
        STATE.hero,
        'rewards_handle_hero_be_hurt',
        string.format('before_hp=%s after_hp=%s max_hp=%s', tostring(before_hp), tostring(STATE.hero:get_hp()), tostring(max_hp))
      )
    end
    remove_expired_temporary_buffs(function(entry)
      return entry.expired == true
    end)
  end

  function api.debug_grant_treasure(treasure_id, replace_slot)
    local def = TREASURE_DEFS[treasure_id]
    if not def then
      return false, '未知宝物。'
    end

    if def.treasure_type == 'tactical_temp' then
      grant_temporary_treasure(def, 'debug')
      return true, string.format('已发放临时宝物：%s。', def.name)
    end

    resolve_treasure_pick(def, replace_slot or get_empty_treasure_slot() or 1)
    return true, string.format('已发放常驻宝物：%s。', def.name)
  end

  function api.debug_dump_temporary_treasures()
    local runtime = api.get_treasure_runtime()
    local lines = {}
    for _, entry in ipairs(runtime.temporary_buffs.active) do
      lines[#lines + 1] = build_temporary_treasure_text(entry)
    end
    return lines
  end

  function api.queue_treasure_round(source_type, source_name)
    local entry = enqueue_reward_entry({
      kind = 'treasure_choice',
      priority = 90,
      source_type = source_type,
      source_name = source_name,
    })

    local runtime = api.get_treasure_runtime()
    if runtime.awaiting_choice or runtime.awaiting_replace then
      message('新的宝物候选已加入待处理队列。')
      return
    end

    if not try_process_reward_queue() and entry and api.get_reward_queue_count() > 0 then
      message('宝物候选已加入待处理队列，完成当前选择后会自动弹出。')
    end
  end

  function api.try_queue_mark_node_for_level(level)
    local node = MARK_NODES_BY_LEVEL[level]
    if not node then
      return false
    end

    local runtime = api.get_mark_runtime()
    if runtime.triggered_node_ids[node.id] then
      return false
    end

    runtime.triggered_node_ids[node.id] = true

    local choices = pick_mark_choices(node.choice_count or 3)
    if #choices == 0 then
      message(string.format('%s：本局没有可用烙印候选。', node.ui_title or '烙印选择'))
      return false
    end

    local round_id = runtime.next_round_id
    runtime.next_round_id = runtime.next_round_id + 1
    runtime.rounds_by_id[round_id] = {
      round_id = round_id,
      node_id = node.id,
      trigger_level = node.trigger_level,
      ui_title = node.ui_title,
      state = 'queued',
      candidate_mark_ids = {},
    }

    for _, def in ipairs(choices) do
      runtime.rounds_by_id[round_id].candidate_mark_ids[#runtime.rounds_by_id[round_id].candidate_mark_ids + 1] = def.id
    end

    enqueue_reward_entry({
      kind = 'mark_choice',
      priority = node.queue_priority or 95,
      round_id = round_id,
      source_name = node.ui_title or '烙印选择',
    })

    if runtime.awaiting_choice then
      message(string.format('%s 已加入待处理奖励队列。', node.ui_title or '烙印选择'))
      return true
    end

    if not try_process_reward_queue() and api.get_reward_queue_count() > 0 then
      message(string.format('%s 已加入待处理奖励队列。', node.ui_title or '烙印选择'))
    end
    return true
  end

  function api.has_pending_treasure_choice()
    local runtime = STATE.treasure_runtime
    return runtime
      and (runtime.awaiting_choice == true or runtime.awaiting_replace == true)
      and true
      or false
  end

  return api
end

return M
