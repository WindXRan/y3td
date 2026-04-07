local M = {}
local BondObjects = require 'entry_objects.bonds'

local BOND_DEF_LIST = BondObjects.defs
local BOND_DEFS = BondObjects.defs_by_id
local BOND_CARD_DEFS = BondObjects.cards
local BOND_CARD_BY_ID = BondObjects.cards_by_id
local BOND_RECIPES = BondObjects.recipes or {}
local BOND_RECIPES_BY_OUTPUT = BondObjects.recipes_by_output_bond_id or {}

local function add_bonus_value(target, key, value)
  if not target or not key or value == nil or value == 0 then
    return
  end
  target[key] = (target[key] or 0) + value
end

local function merge_bonus_pack(target, source)
  if not target or not source then
    return
  end
  for key, value in pairs(source) do
    add_bonus_value(target, key, value)
  end
end

function M.create_runtime()
  return {
    slots = {},
    swallowed_card_ids = {},
    swallowed_bonds = {},
    swallowed_bond_ids = {},
    resolved_recipe_ids = {},
    progress = {},
    active_bond_ids = {},
    applied_attr_bonuses = {},
    applied_runtime_bonuses = {},
    dynamic_attr_bonuses = {},
    dynamic_runtime_bonuses = {},
    current_round = nil,
    current_choices = nil,
    awaiting_choice = false,
    greed_kill_count = 0,
    growth_kill_count = 0,
    hunter_hit_targets = {},
    blessing_elapsed = 0,
    blessing_guard_remaining = 0,
    arcane_empower_remaining = 0,
  }
end

local function make_card_slot(card_id)
  return {
    entry_type = 'card',
    card_id = card_id,
  }
end

local function make_bond_slot(bond_id, source_kind, source_ids)
  return {
    entry_type = 'bond',
    bond_id = bond_id,
    source_kind = source_kind,
    source_ids = source_ids or {},
  }
end

local function get_slot_bond_id(entry)
  if not entry then
    return nil
  end
  if entry.entry_type == 'bond' then
    return entry.bond_id
  end
  if entry.entry_type == 'card' then
    local card = BOND_CARD_BY_ID[entry.card_id]
    return card and card.bond_id or nil
  end
  return nil
end

local function get_refresh_cost(paid_count)
  if (paid_count or 0) <= 0 then
    return 40
  end
  if paid_count == 1 then
    return 80
  end
  return 100
end

function M.get_quality_label(quality)
  if quality == 'legendary' then
    return '传说'
  end
  if quality == 'epic' then
    return '史诗'
  end
  if quality == 'rare' then
    return '稀有'
  end
  return '普通'
end

function M.get_runtime_bonus(state, key)
  local runtime = state and state.bond_runtime
  if not runtime or not key then
    return 0
  end
  return (runtime.applied_runtime_bonuses[key] or 0)
    + (runtime.dynamic_runtime_bonuses[key] or 0)
end

function M.get_progress_count(state, bond_id)
  local runtime = state and state.bond_runtime
  if not runtime or not bond_id then
    return 0
  end
  return runtime.progress[bond_id] or 0
end

function M.is_active(state, bond_id)
  local runtime = state and state.bond_runtime
  return runtime and runtime.active_bond_ids[bond_id] == true or false
end

local function merge_card_effects_by_id(target_attr, target_runtime, card_id)
  local card = BOND_CARD_BY_ID[card_id]
  if not card then
    return
  end
  merge_bonus_pack(target_attr, card.attr)
  merge_bonus_pack(target_runtime, card.runtime)
end

local function is_card_acquired(state, card_id)
  local runtime = state and state.bond_runtime
  if not runtime or not card_id then
    return false
  end

  local card = BOND_CARD_BY_ID[card_id]
  if not card then
    return false
  end
  if card and runtime.swallowed_bond_ids[card.bond_id] == true then
    return true
  end

  for _, entry in ipairs(runtime.slots) do
    if entry.entry_type == 'card' and entry.card_id == card_id then
      return true
    end
    if entry.entry_type == 'bond' and entry.bond_id == card.bond_id then
      return true
    end
  end
  return runtime.swallowed_card_ids[card_id] == true
end

local function record_swallowed_bond(runtime, bond_id, source_kind, source_ids)
  runtime.swallowed_bond_ids[bond_id] = true
  runtime.swallowed_bonds[#runtime.swallowed_bonds + 1] = {
    bond_id = bond_id,
    source_kind = source_kind,
    source_ids = source_ids or {},
  }
end

local function is_recipe_input_bond(bond_id)
  if not bond_id then
    return false
  end
  for _, recipe in ipairs(BOND_RECIPES) do
    for _, input_bond_id in ipairs(recipe.input_bond_ids or {}) do
      if input_bond_id == bond_id then
        return true
      end
    end
  end
  return false
end

local function finalize_completed_bond(runtime, def, source_kind, source_ids)
  local result_type = def.result_type
  if result_type == nil and is_recipe_input_bond(def.id) then
    result_type = 'evolve_keep'
  end

  if result_type == 'evolve_keep' then
    return make_bond_slot(def.id, source_kind, source_ids)
  end

  record_swallowed_bond(runtime, def.id, source_kind, source_ids)
  return nil
end

local function resolve_completed_card_sets(state)
  local runtime = state and state.bond_runtime
  if not runtime then
    return {}
  end

  local by_bond_id = {}
  local kept_slots = {}
  for _, entry in ipairs(runtime.slots) do
    if entry.entry_type == 'card' then
      local bond_id = get_slot_bond_id(entry)
      if bond_id then
        by_bond_id[bond_id] = by_bond_id[bond_id] or {}
        by_bond_id[bond_id][#by_bond_id[bond_id] + 1] = entry.card_id
      end
    else
      kept_slots[#kept_slots + 1] = entry
    end
  end

  local consumed_entries = {}
  for _, def in ipairs(BOND_DEF_LIST) do
    local card_ids = by_bond_id[def.id] or {}
    if #card_ids >= (def.required_count or math.huge) then
      local slot_entry = finalize_completed_bond(runtime, def, 'card_set', card_ids)
      if slot_entry then
        kept_slots[#kept_slots + 1] = slot_entry
      end
      for _, card_id in ipairs(card_ids) do
        runtime.swallowed_card_ids[card_id] = true
      end
      consumed_entries[#consumed_entries + 1] = {
        bond_id = def.id,
        source_kind = 'card_set',
        source_ids = card_ids,
      }
    else
      for _, card_id in ipairs(card_ids) do
        kept_slots[#kept_slots + 1] = make_card_slot(card_id)
      end
    end
  end

  runtime.slots = kept_slots
  return consumed_entries
end

local function try_resolve_recipe_once(state)
  local runtime = state and state.bond_runtime
  if not runtime then
    return nil
  end

  for _, recipe in ipairs(BOND_RECIPES) do
    if not runtime.resolved_recipe_ids[recipe.output_bond_id] then
      local matched_slots = {}
      local used_slot = {}
      for _, input_bond_id in ipairs(recipe.input_bond_ids or {}) do
        for slot, entry in ipairs(runtime.slots) do
          if not used_slot[slot] and entry.entry_type == 'bond' and entry.bond_id == input_bond_id then
            used_slot[slot] = true
            matched_slots[#matched_slots + 1] = slot
            break
          end
        end
      end

      if #matched_slots == #(recipe.input_bond_ids or {}) then
        table.sort(matched_slots, function(a, b)
          return a > b
        end)

        local source_ids = {}
        for _, slot in ipairs(matched_slots) do
          source_ids[#source_ids + 1] = runtime.slots[slot].bond_id
          table.remove(runtime.slots, slot)
        end

        local def = BOND_DEFS[recipe.output_bond_id]
        local slot_entry = finalize_completed_bond(runtime, def, 'recipe', source_ids)
        runtime.resolved_recipe_ids[recipe.output_bond_id] = true
        if slot_entry then
          runtime.slots[#runtime.slots + 1] = slot_entry
        end

        return {
          output_bond_id = recipe.output_bond_id,
          source_ids = source_ids,
        }
      end
    end
  end

  return nil
end

local function resolve_all_recipes(state)
  local resolved = {}
  while true do
    local entry = try_resolve_recipe_once(state)
    if not entry then
      break
    end
    resolved[#resolved + 1] = entry
  end
  return resolved
end

local function get_incomplete_group_count(state)
  local runtime = state and state.bond_runtime
  if not runtime then
    return 0
  end

  local count = 0
  for bond_id, progress in pairs(runtime.progress) do
    local def = BOND_DEFS[bond_id]
    if def and progress > 0 and progress < def.required_count then
      count = count + 1
    end
  end
  return count
end

local function rebuild_progress(state)
  local runtime = state and state.bond_runtime
  if not runtime then
    return
  end

  runtime.progress = {}
  runtime.active_bond_ids = {}

  for _, entry in ipairs(runtime.slots) do
    if entry.entry_type == 'card' then
      local card = BOND_CARD_BY_ID[entry.card_id]
      if card then
        add_bonus_value(runtime.progress, card.bond_id, 1)
      end
    elseif entry.entry_type == 'bond' then
      local def = BOND_DEFS[entry.bond_id]
      if def then
        runtime.progress[entry.bond_id] = def.required_count
        runtime.active_bond_ids[entry.bond_id] = true
      end
    end
  end

  for _, entry in ipairs(runtime.swallowed_bonds or {}) do
    local def = entry.bond_id and BOND_DEFS[entry.bond_id] or nil
    if def then
      runtime.progress[entry.bond_id] = def.required_count
      runtime.active_bond_ids[entry.bond_id] = true
    end
  end
end

function M.refresh_effects(env)
  local state = env.STATE
  local runtime = state and state.bond_runtime
  if not runtime then
    return
  end

  local consumed_entries = resolve_completed_card_sets(state)
  local resolved_recipes = resolve_all_recipes(state)
  rebuild_progress(state)

  local desired_attr = {}
  local desired_runtime = {}
  for _, entry in ipairs(runtime.slots) do
    if entry.entry_type == 'card' then
      merge_card_effects_by_id(desired_attr, desired_runtime, entry.card_id)
    end
  end

  for _, entry in ipairs(runtime.swallowed_bonds or {}) do
    for _, card_id in ipairs(entry.source_kind == 'card_set' and entry.source_ids or {}) do
      merge_card_effects_by_id(desired_attr, desired_runtime, card_id)
    end
  end

  for bond_id in pairs(runtime.active_bond_ids) do
    local def = BOND_DEFS[bond_id]
    if def then
      merge_bonus_pack(desired_attr, def.attr)
      merge_bonus_pack(desired_runtime, def.runtime)
    end
  end

  if state.hero and state.hero:is_exist() then
    local seen = {}
    for attr_name, desired_value in pairs(desired_attr) do
      seen[attr_name] = true
      local prev = runtime.applied_attr_bonuses[attr_name] or 0
      local delta = desired_value - prev
      if delta ~= 0 then
        state.hero:add_attr(attr_name, delta)
        if attr_name == '最大生命' and delta > 0 then
          state.hero:add_hp(delta)
        end
      end
    end

    for attr_name, prev in pairs(runtime.applied_attr_bonuses) do
      if not seen[attr_name] and prev ~= 0 then
        state.hero:add_attr(attr_name, -prev)
      end
    end
  end

  runtime.applied_attr_bonuses = desired_attr
  runtime.applied_runtime_bonuses = desired_runtime
  env.sync_basic_attack_ability()

  return consumed_entries, resolved_recipes
end

local function apply_dynamic_bonuses(env, desired_attr, desired_runtime)
  local state = env.STATE
  local runtime = state and state.bond_runtime
  if not runtime then
    return
  end

  if state.hero and state.hero:is_exist() then
    local seen_attr = {}
    for attr_name, desired_value in pairs(desired_attr) do
      seen_attr[attr_name] = true
      local prev = runtime.dynamic_attr_bonuses[attr_name] or 0
      local delta = desired_value - prev
      if delta ~= 0 then
        state.hero:add_attr(attr_name, delta)
      end
    end

    for attr_name, prev in pairs(runtime.dynamic_attr_bonuses) do
      if not seen_attr[attr_name] and prev ~= 0 then
        state.hero:add_attr(attr_name, -prev)
      end
    end
  end

  runtime.dynamic_attr_bonuses = desired_attr
  runtime.dynamic_runtime_bonuses = desired_runtime
  env.sync_basic_attack_ability()
end

function M.update_effects(env, dt)
  local state = env.STATE
  local runtime = state and state.bond_runtime
  if not runtime or not state.hero or not state.hero:is_exist() then
    return
  end

  local desired_attr = {}
  local desired_runtime = {}
  local max_hp = math.max(1, env.y3.helper.tonumber(state.hero:get_attr('最大生命')) or 1)
  local hp_ratio = math.max(0, state.hero:get_hp() / max_hp)

  if M.is_active(state, 'blessing') then
    runtime.blessing_elapsed = runtime.blessing_elapsed + dt
    if runtime.blessing_elapsed >= 8 then
      runtime.blessing_elapsed = runtime.blessing_elapsed - 8
      env.heal_hero(max_hp * 0.06)
      runtime.blessing_guard_remaining = 2
    end
  else
    runtime.blessing_elapsed = 0
    runtime.blessing_guard_remaining = 0
  end

  if runtime.blessing_guard_remaining > 0 then
    runtime.blessing_guard_remaining = math.max(0, runtime.blessing_guard_remaining - dt)
    add_bonus_value(desired_attr, '伤害减免', 8)
  end

  if M.is_active(state, 'berserk') and hp_ratio <= 0.50 then
    add_bonus_value(desired_attr, '攻击速度', 35)
    add_bonus_value(desired_runtime, 'normal_attack_damage_bonus', 0.25)
  end

  if M.is_active(state, 'arcane') then
    runtime.arcane_empower_remaining = math.max(0, runtime.arcane_empower_remaining - dt)
    if runtime.arcane_empower_remaining > 0 then
      add_bonus_value(desired_runtime, 'all_damage_bonus', 0.12)
    end
  else
    runtime.arcane_empower_remaining = 0
  end

  if M.is_active(state, 'fortress') then
    if hp_ratio >= 0.80 then
      add_bonus_value(desired_attr, '伤害减免', 12)
    end
    if hp_ratio <= 0.50 then
      env.heal_hero(max_hp * 0.03 * dt)
    end
  end

  apply_dynamic_bonuses(env, desired_attr, desired_runtime)
end

function M.build_reward_with_bonus(env, reward)
  if not reward then
    return nil
  end

  local result = {
    gold = reward.gold or 0,
    wood = reward.wood or 0,
    exp = reward.exp or 0,
    special = reward.special,
  }

  local reward_ratio = M.get_runtime_bonus(env.STATE, 'kill_reward_ratio')
  if reward_ratio > 0 then
    result.gold = result.gold + env.round_number(result.gold * reward_ratio)
    result.wood = result.wood + env.round_number(result.wood * reward_ratio)
    result.exp = result.exp + env.round_number(result.exp * reward_ratio)
  end

  local gold_ratio = M.get_runtime_bonus(env.STATE, 'kill_gold_ratio')
  if gold_ratio > 0 and result.gold > 0 then
    result.gold = result.gold + env.round_number((reward.gold or 0) * gold_ratio)
  end

  return result
end

function M.try_trigger_hunter_first_hit(env, target)
  local state = env.STATE
  local ratio = M.get_runtime_bonus(state, 'hunter_first_hit_ratio')
  if ratio <= 0 or not target or not env.is_active_enemy(target) then
    return
  end

  local info = env.get_enemy_runtime_info(target)
  if not env.is_boss_runtime_enemy(info) and not env.is_elite_runtime_enemy(info) then
    return
  end

  local runtime = state.bond_runtime
  if not runtime or runtime.hunter_hit_targets[target] then
    return
  end

  runtime.hunter_hit_targets[target] = true
  state.hero:damage({
    target = target,
    damage = env.round_number(state.hero:get_attr('物理攻击') * ratio),
    type = env.basic_attack_damage_type,
    text_type = 'physics',
    common_attack = false,
    no_miss = true,
  })
end

function M.handle_enemy_kill(env, info)
  local state = env.STATE
  local runtime = state and state.bond_runtime
  if not runtime or not state.hero or not state.hero:is_exist() then
    return
  end

  local attack_on_kill = env.round_number(M.get_runtime_bonus(state, 'attack_on_kill'))
  if attack_on_kill > 0 then
    state.hero:add_attr('物理攻击', attack_on_kill)
  end

  if M.is_active(state, 'greed') then
    runtime.greed_kill_count = runtime.greed_kill_count + 1
    while runtime.greed_kill_count >= 30 do
      runtime.greed_kill_count = runtime.greed_kill_count - 30
      state.resources.gold = state.resources.gold + 30
      state.resources.wood = state.resources.wood + 40
      env.message('贪欲羁绊触发：金币 +30，木材 +40。')
    end
  end

  if M.is_active(state, 'growth') then
    local before_kills = runtime.growth_kill_count
    runtime.growth_kill_count = runtime.growth_kill_count + 1

    if math.floor(before_kills / 20) ~= math.floor(runtime.growth_kill_count / 20) then
      state.hero:add_attr('物理攻击', 12)
      env.message('成长羁绊触发：永久物理攻击 +12。')
    end
    if math.floor(before_kills / 100) ~= math.floor(runtime.growth_kill_count / 100) then
      state.hero:add_attr('伤害加成', 4)
      env.message('成长羁绊进阶：伤害加成 +4%。')
    end
  end
end

local function get_quality_weights(state)
  local wave_index = math.max(1, state.current_wave_index or 0, state.started_wave_count or 0)
  if wave_index <= 2 then
    return { common = 100, rare = 40, epic = 8 }
  end
  if wave_index == 3 then
    return { common = 70, rare = 70, epic = 18 }
  end
  if wave_index == 4 then
    return { common = 40, rare = 80, epic = 35 }
  end
  return { common = 25, rare = 70, epic = 55 }
end

local function pick_weighted_card(state, excluded_bond_ids)
  local quality_weights = get_quality_weights(state)
  local incomplete_group_count = get_incomplete_group_count(state)
  local pool = {}
  local total_weight = 0

  for _, card in ipairs(BOND_CARD_DEFS) do
    if not is_card_acquired(state, card.id)
      and not (excluded_bond_ids and excluded_bond_ids[card.bond_id]) then
      local bond = BOND_DEFS[card.bond_id]
      if bond then
        local progress = M.get_progress_count(state, card.bond_id)
        local weight = (bond.pool_weight or 1) * (quality_weights[card.quality] or 1)

        if progress == 0 then
          if incomplete_group_count >= 2 then
            weight = weight * 0.6
          end
        elseif progress == 1 then
          weight = weight * 1.8
        elseif progress == 2 then
          weight = weight * 2.4
        else
          weight = weight * 3.0
        end

        if progress >= bond.required_count then
          weight = weight * 0.8
        end

        if weight > 0 then
          total_weight = total_weight + weight
          pool[#pool + 1] = {
            card = card,
            weight = weight,
          }
        end
      end
    end
  end

  if #pool == 0 or total_weight <= 0 then
    return nil
  end

  local roll = math.random() * total_weight
  local cumulative = 0
  for _, entry in ipairs(pool) do
    cumulative = cumulative + entry.weight
    if roll <= cumulative then
      return entry.card
    end
  end

  return pool[#pool].card
end

local function pick_choices(state, count)
  local choices = {}
  local excluded_bond_ids = {}

  while #choices < count do
    local picked = pick_weighted_card(state, excluded_bond_ids)
    if not picked then
      break
    end

    excluded_bond_ids[picked.bond_id] = true
    choices[#choices + 1] = picked
  end

  return choices
end

local function build_slot_text(state, slot)
  local runtime = state and state.bond_runtime
  local entry = runtime and runtime.slots[slot] or nil
  if not entry then
    return string.format('%d号羁绊位 空', slot)
  end

  if entry.entry_type == 'card' then
    local card = BOND_CARD_BY_ID[entry.card_id]
    local bond = card and BOND_DEFS[card.bond_id] or nil
    if not card or not bond then
      return string.format('%d号羁绊位 空', slot)
    end

    local progress = M.get_progress_count(state, card.bond_id)
    return string.format(
      '%d号羁绊位 [%s]%s-%s | %d/%d | %s',
      slot,
      M.get_quality_label(card.quality),
      bond.name,
      card.name,
      progress,
      bond.required_count,
      card.base_effect_desc
    )
  end

  local bond = BOND_DEFS[entry.bond_id]
  if not bond then
    return string.format('%d号羁绊位 空', slot)
  end

  return string.format(
    '%d号羁绊位 [%s]%s | 已成型 | %s',
    slot,
    M.get_quality_label(bond.quality),
    bond.name,
    bond.bond_effect_desc
  )
end

function M.show_loadout(env)
  env.message('羁绊栏：')
  for slot = 1, 7, 1 do
    env.message(build_slot_text(env.STATE, slot))
  end
end

M.build_slot_text = build_slot_text

local function build_swallowed_bond_text(index, entry)
  local bond = entry and BOND_DEFS[entry.bond_id] or nil
  if not bond then
    return string.format('%d. 未知羁绊', index)
  end

  if entry.source_kind == 'recipe' then
    return string.format(
      '%d. [%s]%s | 配方：%s | 成套：%s',
      index,
      M.get_quality_label(bond.quality),
      bond.name,
      table.concat(entry.source_ids or {}, ' + '),
      bond.bond_effect_desc
    )
  end

  local card_parts = {}
  for _, card_id in ipairs(entry.card_ids or entry.source_ids or {}) do
    local card = BOND_CARD_BY_ID[card_id]
    if card then
      card_parts[#card_parts + 1] = string.format('%s(%s)', card.name, card.base_effect_desc)
    end
  end

  local card_text = #card_parts > 0 and table.concat(card_parts, '、') or '无'
  return string.format(
    '%d. [%s]%s | 单卡：%s | 成套：%s',
    index,
    M.get_quality_label(bond.quality),
    bond.name,
    card_text,
    bond.bond_effect_desc
  )
end

function M.show_swallowed_bonds(env)
  local runtime = env and env.STATE and env.STATE.bond_runtime
  if not runtime or #runtime.swallowed_bonds == 0 then
    env.message('已吞噬羁绊：暂无。')
    return
  end

  env.message('已吞噬羁绊（效果保留）：')
  for index, entry in ipairs(runtime.swallowed_bonds) do
    env.message(build_swallowed_bond_text(index, entry))
  end
end

M.build_swallowed_bond_text = build_swallowed_bond_text

local function build_choice_text(state, index, card)
  local bond = card and BOND_DEFS[card.bond_id] or nil
  if not card or not bond then
    return string.format('%d. 空', index)
  end

  local current_count = M.get_progress_count(state, card.bond_id)
  local next_count = math.min(bond.required_count, current_count + 1)
  return string.format(
    '%d. [%s][%s %d/%d] %s | 单卡:%s | 成套:%s',
    index,
    M.get_quality_label(card.quality),
    bond.name,
    next_count,
    bond.required_count,
    card.name,
    card.base_effect_desc,
    bond.bond_effect_desc
  )
end

local function get_replace_score(state, entry, incoming_card)
  local bond_id = get_slot_bond_id(entry)
  local bond = bond_id and BOND_DEFS[bond_id] or nil
  if not bond then
    return -9999
  end

  if entry.entry_type == 'bond' then
    return -500
  end

  local card = BOND_CARD_BY_ID[entry.card_id]
  if not card then
    return -9999
  end

  if incoming_card and incoming_card.bond_id == card.bond_id then
    local incoming_bond = BOND_DEFS[incoming_card.bond_id]
    if incoming_bond and M.get_progress_count(state, incoming_card.bond_id) + 1 >= incoming_bond.required_count then
      return -999999
    end
  end

  local progress = M.get_progress_count(state, card.bond_id)
  local score = 0
  if progress <= 1 then
    score = score + 35
  end
  if progress < bond.required_count then
    score = score + 30
  else
    score = score - 100
  end
  if progress - 1 >= bond.required_count then
    score = score + 120
  end

  if card.quality == 'common' then
    score = score + 20
  elseif card.quality == 'rare' then
    score = score + 8
  else
    score = score - 10
  end

  return score
end

local function pick_replace_slot(state, incoming_card)
  local runtime = state and state.bond_runtime
  if not runtime or #runtime.slots == 0 then
    return nil
  end

  local best_slot = 1
  local best_score = -999999
  for slot, entry in ipairs(runtime.slots) do
    local score = get_replace_score(state, entry, incoming_card)
    if score > best_score then
      best_score = score
      best_slot = slot
    end
  end
  return best_slot
end

function M.apply_choice(env, index)
  local state = env.STATE
  local runtime = state and state.bond_runtime
  if not runtime or not runtime.awaiting_choice then
    return
  end

  local card = runtime.current_choices and runtime.current_choices[index]
  if not card then
    return
  end

  local previous_active = {}
  for bond_id in pairs(runtime.active_bond_ids) do
    previous_active[bond_id] = true
  end

  local previous_swallowed_count = #runtime.swallowed_bonds
  local replaced_card = nil
  local replace_slot = nil
  if #runtime.slots >= 7 then
    replace_slot = pick_replace_slot(state, card) or 1
    replaced_card = runtime.slots[replace_slot]
    if replaced_card and replaced_card.entry_type == 'card' then
      runtime.swallowed_card_ids[replaced_card.card_id] = true
    end
    runtime.slots[replace_slot] = make_card_slot(card.id)
  else
    runtime.slots[#runtime.slots + 1] = make_card_slot(card.id)
  end

  runtime.awaiting_choice = false
  runtime.current_round = nil
  runtime.current_choices = nil

  local consumed_entries, resolved_recipes = M.refresh_effects(env)
  local swallowed_entries = {}
  for entry_index = previous_swallowed_count + 1, #runtime.swallowed_bonds, 1 do
    swallowed_entries[#swallowed_entries + 1] = runtime.swallowed_bonds[entry_index]
  end

  local bond = BOND_DEFS[card.bond_id]
  env.message(string.format('已选择羁绊卡：[%s]%s-%s。', M.get_quality_label(card.quality), bond.name, card.name))
  if replaced_card then
    if replaced_card.entry_type == 'card' then
      local old_card = BOND_CARD_BY_ID[replaced_card.card_id]
      local old_bond = old_card and BOND_DEFS[old_card.bond_id] or nil
      if old_card and old_bond then
        env.message(string.format('当前羁绊位已满，已自动吞噬第 %d 格：%s-%s。', replace_slot, old_bond.name, old_card.name))
      end
    elseif replaced_card.entry_type == 'bond' then
      local old_bond = BOND_DEFS[replaced_card.bond_id]
      if old_bond then
        env.message(string.format('当前羁绊位已满，已移出第 %d 格已成型羁绊：%s。', replace_slot, old_bond.name))
      end
    end
  end

  for _, entry in ipairs(consumed_entries or {}) do
    local activated_bond = BOND_DEFS[entry.bond_id]
    if activated_bond and activated_bond.result_type == 'evolve_keep' then
      env.message(string.format(
        '羁绊成型：[%s]%s 已占用羁绊位。%s',
        M.get_quality_label(activated_bond.quality),
        activated_bond.name,
        activated_bond.bond_effect_desc
      ))
    end
  end

  for _, entry in ipairs(resolved_recipes or {}) do
    local resolved_bond = BOND_DEFS[entry.output_bond_id]
    if resolved_bond then
      env.message(string.format(
        '配方进化：[%s]%s <- %s。',
        M.get_quality_label(resolved_bond.quality),
        resolved_bond.name,
        table.concat(entry.source_ids or {}, ' + ')
      ))
    end
  end

  for bond_id in pairs(runtime.active_bond_ids) do
    if not previous_active[bond_id] and not BOND_RECIPES_BY_OUTPUT[bond_id] then
      local activated_bond = BOND_DEFS[bond_id]
      if activated_bond and activated_bond.result_type ~= 'evolve_keep' then
        env.message(string.format('羁绊激活：%s %d/%d。%s', activated_bond.name, activated_bond.required_count, activated_bond.required_count, activated_bond.bond_effect_desc))
      end
    end
  end

  for _, entry in ipairs(swallowed_entries) do
    local swallowed_bond = BOND_DEFS[entry.bond_id]
    if swallowed_bond then
      env.message(string.format(
        '羁绊整套吞噬：%s 已移出羁绊栏，效果保留，释放 %d 格。按 I 可查看已吞噬列表。',
        swallowed_bond.name,
        #(entry.card_ids or entry.source_ids or {})
      ))
    end
  end

  M.show_loadout(env)
  if #swallowed_entries > 0 then
    M.show_swallowed_bonds(env)
  end
end

function M.debug_grant_card(env, card_id)
  local state = env and env.STATE
  local runtime = state and state.bond_runtime
  local card = BOND_CARD_BY_ID[card_id]
  if not runtime or not card then
    return false, '未知羁绊卡。'
  end
  if #runtime.slots >= 7 then
    return false, '当前羁绊位已满，请先让已有羁绊成型或吞噬。'
  end

  runtime.slots[#runtime.slots + 1] = make_card_slot(card_id)
  M.refresh_effects(env)
  return true, string.format('已发放羁绊卡：%s。', card.name)
end

function M.try_draw(env)
  local state = env.STATE
  local runtime = state.bond_runtime
  local cost_wood = 100
  if not runtime then
    runtime = M.create_runtime()
    state.bond_runtime = runtime
  end

  if state.awaiting_upgrade then
    env.message('请先完成当前 G 三选一。')
    return
  end

  if runtime.awaiting_choice and runtime.current_choices then
    env.message('继续当前 F 羁绊三选一。')
    for index, card in ipairs(runtime.current_choices) do
      env.message(build_choice_text(state, index, card))
    end
    return
  end

  if state.resources.wood < cost_wood then
    env.message('木材不足，无法进行羁绊抽卡。')
    return
  end

  local choices = pick_choices(state, 3)
  if #choices == 0 then
    env.message('当前没有可抽取的羁绊卡。')
    return
  end

  state.resources.wood = state.resources.wood - cost_wood
  state.bond_draw_count = state.bond_draw_count + 1
  runtime.awaiting_choice = true
  runtime.current_round = {
    free_refresh_left = 0,
    refresh_paid_count = 0,
  }
  runtime.current_choices = choices

  env.message('羁绊抽卡 3选1：按 1 / 2 / 3 选择。')
  if #runtime.slots >= 7 then
    env.message('当前已持有 7 张生效羁绊卡，选择后将按推荐自动吞噬 1 张旧卡。')
  end
  for index, card in ipairs(choices) do
    env.message(build_choice_text(state, index, card))
  end
  M.show_loadout(env)
end

function M.refresh_choice(env)
  local state = env.STATE
  local runtime = state and state.bond_runtime
  if not runtime or not runtime.awaiting_choice or not runtime.current_choices then
    return false
  end

  local choices = pick_choices(state, 3)
  if #choices == 0 then
    env.message('当前没有可刷新的羁绊卡候选。')
    return false
  end

  runtime.current_round = runtime.current_round or {
    free_refresh_left = 0,
    refresh_paid_count = 0,
  }

  if (runtime.current_round.free_refresh_left or 0) > 0 then
    runtime.current_round.free_refresh_left = runtime.current_round.free_refresh_left - 1
    env.message(string.format('已免费刷新 F 羁绊三选一，剩余免费次数 %d。', runtime.current_round.free_refresh_left))
  else
    local cost = get_refresh_cost(runtime.current_round.refresh_paid_count or 0)
    local wood = state.resources and state.resources.wood or 0
    if wood < cost then
      env.message(string.format('木材不足，刷新 F 羁绊三选一需要 %d 木材。', cost))
      return false
    end
    state.resources.wood = wood - cost
    runtime.current_round.refresh_paid_count = (runtime.current_round.refresh_paid_count or 0) + 1
    env.message(string.format('已消耗 %d 木材刷新 F 羁绊三选一。', cost))
  end

  runtime.current_choices = choices
  return true
end

return M
