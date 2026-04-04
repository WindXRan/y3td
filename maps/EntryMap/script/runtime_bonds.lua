local M = {}

local BOND_DEFS = {
  blessing = {
    id = 'blessing',
    name = '祝福',
    quality = 'common',
    required_count = 2,
    pool_weight = 10,
    bond_effect_desc = '每8秒回复6%最大生命，并获得8%伤害减免，持续2秒。',
    runtime = { blessing_active = 1 },
  },
  berserk = {
    id = 'berserk',
    name = '狂战',
    quality = 'common',
    required_count = 2,
    pool_weight = 10,
    bond_effect_desc = '生命低于50%时，额外获得攻速+35%与普攻伤害+25%。',
    runtime = { berserk_active = 1 },
  },
  hunter = {
    id = 'hunter',
    name = '猎手',
    quality = 'common',
    required_count = 2,
    pool_weight = 9,
    bond_effect_desc = '对精英与Boss伤害额外+25%，首次命中时追加50%攻击力伤害。',
    runtime = {
      boss_damage_bonus = 0.25,
      elite_damage_bonus = 0.25,
      hunter_first_hit_ratio = 0.50,
    },
  },
  greed = {
    id = 'greed',
    name = '贪欲',
    quality = 'common',
    required_count = 2,
    pool_weight = 9,
    bond_effect_desc = '每击杀30个敌人，额外获得40木材与30金币。',
    runtime = { greed_active = 1 },
  },
  barrage = {
    id = 'barrage',
    name = '连射',
    quality = 'rare',
    required_count = 3,
    pool_weight = 8,
    bond_effect_desc = '多重数量+1，多重伤害+35%。',
    runtime = {
      multishot_count = 1,
      multishot_ratio = 0.35,
    },
  },
  chain = {
    id = 'chain',
    name = '连锁',
    quality = 'rare',
    required_count = 3,
    pool_weight = 8,
    bond_effect_desc = '弹射次数+1，弹射伤害+35%。',
    runtime = {
      chain_bounces = 1,
      chain_ratio = 0.35,
    },
  },
  arcane = {
    id = 'arcane',
    name = '奥术',
    quality = 'rare',
    required_count = 3,
    pool_weight = 8,
    bond_effect_desc = '技能伤害+35%，释放攻击技能后3秒内所有伤害+12%。',
    runtime = {
      skill_damage_bonus = 0.35,
      arcane_empower_enabled = 1,
    },
  },
  execute = {
    id = 'execute',
    name = '处决',
    quality = 'rare',
    required_count = 3,
    pool_weight = 8,
    bond_effect_desc = '对生命低于35%的敌人造成的伤害额外+40%。',
    runtime = {
      execute_damage_bonus = 0.40,
      execute_threshold = 0.35,
    },
  },
  growth = {
    id = 'growth',
    name = '成长',
    quality = 'epic',
    required_count = 4,
    pool_weight = 6,
    bond_effect_desc = '每击杀20个敌人永久攻击+12；每100击杀额外获得伤害加成+4%。',
    runtime = { growth_active = 1 },
  },
  fortress = {
    id = 'fortress',
    name = '坚壁',
    quality = 'epic',
    required_count = 4,
    pool_weight = 6,
    bond_effect_desc = '生命高于80%时伤害减免+12；生命低于50%时每秒回复3%最大生命。',
    runtime = { fortress_active = 1 },
  },
}

local BOND_CARD_DEFS = {
  {
    id = 'blessing_holy_water',
    bond_id = 'blessing',
    name = '圣水',
    quality = 'common',
    base_effect_desc = '生命恢复 +8',
    attr = { ['生命恢复'] = 8 },
  },
  {
    id = 'blessing_prayer',
    bond_id = 'blessing',
    name = '祈愿',
    quality = 'common',
    base_effect_desc = '最大生命 +160',
    attr = { ['最大生命'] = 160 },
  },
  {
    id = 'berserk_fury',
    bond_id = 'berserk',
    name = '怒意',
    quality = 'common',
    base_effect_desc = '物理攻击 +18',
    attr = { ['物理攻击'] = 18 },
  },
  {
    id = 'berserk_hot_blood',
    bond_id = 'berserk',
    name = '热血',
    quality = 'common',
    base_effect_desc = '攻击速度 +12%',
    attr = { ['攻击速度'] = 12 },
  },
  {
    id = 'hunter_pursuit',
    bond_id = 'hunter',
    name = '追猎',
    quality = 'common',
    base_effect_desc = 'Boss伤害 +12%',
    runtime = { boss_damage_bonus = 0.12 },
  },
  {
    id = 'hunter_purge',
    bond_id = 'hunter',
    name = '剿灭',
    quality = 'common',
    base_effect_desc = '精英伤害 +12%',
    runtime = { elite_damage_bonus = 0.12 },
  },
  {
    id = 'greed_coin',
    bond_id = 'greed',
    name = '铜币',
    quality = 'common',
    base_effect_desc = '杀敌金币 +20%',
    runtime = { kill_gold_ratio = 0.20 },
  },
  {
    id = 'greed_hoard',
    bond_id = 'greed',
    name = '囤积',
    quality = 'common',
    base_effect_desc = '每秒金币 +2',
    runtime = { gold_per_sec_bonus = 2 },
  },
  {
    id = 'barrage_swiftstring',
    bond_id = 'barrage',
    name = '疾弦',
    quality = 'rare',
    base_effect_desc = '攻击速度 +10%',
    attr = { ['攻击速度'] = 10 },
  },
  {
    id = 'barrage_draw',
    bond_id = 'barrage',
    name = '开弓',
    quality = 'rare',
    base_effect_desc = '普攻伤害 +12%',
    runtime = { normal_attack_damage_bonus = 0.12 },
  },
  {
    id = 'barrage_spread',
    bond_id = 'barrage',
    name = '扩散',
    quality = 'rare',
    base_effect_desc = '多重伤害 +15%',
    runtime = { multishot_ratio = 0.15 },
  },
  {
    id = 'chain_echo',
    bond_id = 'chain',
    name = '回响',
    quality = 'rare',
    base_effect_desc = '弹射伤害 +15%',
    runtime = { chain_ratio = 0.15 },
  },
  {
    id = 'chain_return',
    bond_id = 'chain',
    name = '折返',
    quality = 'rare',
    base_effect_desc = '攻击范围 +40',
    attr = { ['攻击范围'] = 40 },
  },
  {
    id = 'chain_pursue',
    bond_id = 'chain',
    name = '追击',
    quality = 'rare',
    base_effect_desc = '普攻伤害 +10%',
    runtime = { normal_attack_damage_bonus = 0.10 },
  },
  {
    id = 'arcane_chant',
    bond_id = 'arcane',
    name = '咏唱',
    quality = 'rare',
    base_effect_desc = '技能伤害 +12%',
    runtime = { skill_damage_bonus = 0.12 },
  },
  {
    id = 'arcane_conduit',
    bond_id = 'arcane',
    name = '导能',
    quality = 'rare',
    base_effect_desc = '伤害加成 +8%',
    attr = { ['伤害加成'] = 8 },
  },
  {
    id = 'arcane_focus',
    bond_id = 'arcane',
    name = '聚焦',
    quality = 'rare',
    base_effect_desc = '攻击范围 +40',
    attr = { ['攻击范围'] = 40 },
  },
  {
    id = 'execute_weakness',
    bond_id = 'execute',
    name = '破绽',
    quality = 'rare',
    base_effect_desc = '普攻伤害 +10%',
    runtime = { normal_attack_damage_bonus = 0.10 },
  },
  {
    id = 'execute_suppress',
    bond_id = 'execute',
    name = '压制',
    quality = 'rare',
    base_effect_desc = '精英伤害 +10%',
    runtime = { elite_damage_bonus = 0.10 },
  },
  {
    id = 'execute_thrust',
    bond_id = 'execute',
    name = '突刺',
    quality = 'rare',
    base_effect_desc = '物理攻击 +16',
    attr = { ['物理攻击'] = 16 },
  },
  {
    id = 'growth_hone',
    bond_id = 'growth',
    name = '磨砺',
    quality = 'epic',
    base_effect_desc = '伤害加成 +8%',
    attr = { ['伤害加成'] = 8 },
  },
  {
    id = 'growth_accumulate',
    bond_id = 'growth',
    name = '积累',
    quality = 'epic',
    base_effect_desc = '杀敌攻击 +1',
    runtime = { attack_on_kill = 1 },
  },
  {
    id = 'growth_merit',
    bond_id = 'growth',
    name = '历战',
    quality = 'epic',
    base_effect_desc = '杀敌奖励 +10%',
    runtime = { kill_reward_ratio = 0.10 },
  },
  {
    id = 'growth_charge',
    bond_id = 'growth',
    name = '蓄势',
    quality = 'epic',
    base_effect_desc = '物理攻击 +20',
    attr = { ['物理攻击'] = 20 },
  },
  {
    id = 'fortress_iron',
    bond_id = 'fortress',
    name = '铁甲',
    quality = 'epic',
    base_effect_desc = '最大生命 +180',
    attr = { ['最大生命'] = 180 },
  },
  {
    id = 'fortress_wall',
    bond_id = 'fortress',
    name = '壁垒',
    quality = 'epic',
    base_effect_desc = '伤害减免 +4%',
    attr = { ['伤害减免'] = 4 },
  },
  {
    id = 'fortress_heal',
    bond_id = 'fortress',
    name = '自愈',
    quality = 'epic',
    base_effect_desc = '生命恢复 +10',
    attr = { ['生命恢复'] = 10 },
  },
  {
    id = 'fortress_stable',
    bond_id = 'fortress',
    name = '稳固',
    quality = 'epic',
    base_effect_desc = '护甲 +6',
    attr = { ['护甲'] = 6 },
  },
}

local BOND_CARD_BY_ID = {}
for _, card in ipairs(BOND_CARD_DEFS) do
  BOND_CARD_BY_ID[card.id] = card
end

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
    progress = {},
    active_bond_ids = {},
    applied_attr_bonuses = {},
    applied_runtime_bonuses = {},
    dynamic_attr_bonuses = {},
    dynamic_runtime_bonuses = {},
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

function M.get_quality_label(quality)
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

local function is_card_acquired(state, card_id)
  local runtime = state and state.bond_runtime
  if not runtime or not card_id then
    return false
  end

  for _, owned_card_id in ipairs(runtime.slots) do
    if owned_card_id == card_id then
      return true
    end
  end
  return runtime.swallowed_card_ids[card_id] == true
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

  for _, card_id in ipairs(runtime.slots) do
    local card = BOND_CARD_BY_ID[card_id]
    if card then
      add_bonus_value(runtime.progress, card.bond_id, 1)
    end
  end

  for bond_id, def in pairs(BOND_DEFS) do
    if (runtime.progress[bond_id] or 0) >= def.required_count then
      runtime.active_bond_ids[bond_id] = true
    end
  end
end

function M.refresh_effects(env)
  local state = env.STATE
  local runtime = state and state.bond_runtime
  if not runtime then
    return
  end

  rebuild_progress(state)

  local desired_attr = {}
  local desired_runtime = {}
  for _, card_id in ipairs(runtime.slots) do
    local card = BOND_CARD_BY_ID[card_id]
    if card then
      merge_bonus_pack(desired_attr, card.attr)
      merge_bonus_pack(desired_runtime, card.runtime)
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
  local card_id = runtime and runtime.slots[slot] or nil
  if not card_id then
    return string.format('%d号羁绊位 空', slot)
  end

  local card = BOND_CARD_BY_ID[card_id]
  local bond = card and BOND_DEFS[card.bond_id] or nil
  if not card or not bond then
    return string.format('%d号羁绊位 空', slot)
  end

  local progress = M.get_progress_count(state, card.bond_id)
  local state_text = M.is_active(state, card.bond_id)
    and '已激活'
    or string.format('%d/%d', progress, bond.required_count)
  return string.format(
    '%d号羁绊位 [%s]%s-%s | %s | %s',
    slot,
    M.get_quality_label(card.quality),
    bond.name,
    card.name,
    state_text,
    card.base_effect_desc
  )
end

function M.show_loadout(env)
  env.message('羁绊栏：')
  for slot = 1, 7, 1 do
    env.message(build_slot_text(env.STATE, slot))
  end
end

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

local function get_replace_score(state, card_id)
  local card = BOND_CARD_BY_ID[card_id]
  local bond = card and BOND_DEFS[card.bond_id] or nil
  if not card or not bond then
    return -9999
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

local function pick_replace_slot(state)
  local runtime = state and state.bond_runtime
  if not runtime or #runtime.slots == 0 then
    return nil
  end

  local best_slot = 1
  local best_score = -999999
  for slot, card_id in ipairs(runtime.slots) do
    local score = get_replace_score(state, card_id)
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

  local replaced_card = nil
  local replace_slot = nil
  if #runtime.slots >= 7 then
    replace_slot = pick_replace_slot(state) or 1
    replaced_card = runtime.slots[replace_slot]
    if replaced_card then
      runtime.swallowed_card_ids[replaced_card] = true
    end
    runtime.slots[replace_slot] = card.id
  else
    runtime.slots[#runtime.slots + 1] = card.id
  end

  runtime.awaiting_choice = false
  runtime.current_choices = nil

  M.refresh_effects(env)

  local bond = BOND_DEFS[card.bond_id]
  env.message(string.format('已选择羁绊卡：[%s]%s-%s。', M.get_quality_label(card.quality), bond.name, card.name))
  if replaced_card then
    local old_card = BOND_CARD_BY_ID[replaced_card]
    local old_bond = old_card and BOND_DEFS[old_card.bond_id] or nil
    if old_card and old_bond then
      env.message(string.format('当前羁绊位已满，已自动吞噬第 %d 格：%s-%s。', replace_slot, old_bond.name, old_card.name))
    end
  end

  for bond_id in pairs(runtime.active_bond_ids) do
    if not previous_active[bond_id] then
      local activated_bond = BOND_DEFS[bond_id]
      if activated_bond then
        env.message(string.format('羁绊激活：%s %d/%d。%s', activated_bond.name, activated_bond.required_count, activated_bond.required_count, activated_bond.bond_effect_desc))
      end
    end
  end

  M.show_loadout(env)
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

return M
