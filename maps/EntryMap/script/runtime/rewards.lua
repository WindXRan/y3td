local HeroEvolutionObjects = require 'data.tables.outgame.hero_evolutions'
local HeroEvolutionNodeObjects = require 'data.tables.outgame.hero_evolution_nodes'
local HeroRoster = (require 'data.game_tables').hero_roster

local M = {}
local y3 = y3

local EVOLUTION_QUALITY_LABELS = {
  common = '普通',
  rare = '稀有',
  epic = '史诗',
}

local EVOLUTION_DEF_LIST = HeroEvolutionObjects.list
local EVOLUTION_DEFS = HeroEvolutionObjects.by_id
local EVOLUTION_NODES_BY_LEVEL = HeroEvolutionNodeObjects.by_level
local EVOLUTION_POOL_RULES = HeroEvolutionNodeObjects.pool_rules_by_id or {}
local HERO_ROSTER_BY_UNIT_ID = HeroRoster.by_unit_id or {}

local CHOICE_COUNT = 3

local function round_number(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function add_pack(target, source)
  for attr_name, value in pairs(source or {}) do
    local number = tonumber(value) or 0
    if number ~= 0 then
      target[attr_name] = (target[attr_name] or 0) + number
    end
  end
  return target
end

local function copy_pack(source)
  local result = {}
  return add_pack(result, source)
end

local function format_pack(pack)
  local lines = {}
  local order = { '攻击', '生命', '护甲', '力量', '敏捷', '智力' }
  local used = {}
  for _, attr_name in ipairs(order) do
    local value = tonumber(pack and pack[attr_name] or 0) or 0
    if value ~= 0 then
      lines[#lines + 1] = string.format('%s +%d', attr_name, round_number(value))
      used[attr_name] = true
    end
  end
  for attr_name, value in pairs(pack or {}) do
    if not used[attr_name] and value ~= 0 then
      lines[#lines + 1] = string.format('%s +%d', tostring(attr_name), round_number(value))
    end
  end
  return table.concat(lines, '\n')
end

local function build_choices(level)
  local final_level = math.max(1, tonumber(level) or 1)
  local attack = 10 + final_level * 2
  local armor = 2 + math.floor(final_level / 3)
  local main_attr = 3 + math.floor(final_level / 4)

  local choices = {
    {
      id = 'attack',
      title_text = '攻击',
      subtitle_text = '攻击成长',
      attr_pack = { ['攻击'] = attack },
    },
    {
      id = 'armor',
      title_text = '护甲',
      subtitle_text = '护甲成长',
      attr_pack = { ['护甲'] = armor },
    },
    {
      id = 'main_attr',
      title_text = '全属性',
      subtitle_text = '全主属性',
      attr_pack = { ['力量'] = main_attr, ['敏捷'] = main_attr, ['智力'] = main_attr },
      body_text = string.format('全属性 +%d', main_attr),
    },
  }

  for index, choice in ipairs(choices) do
    choice.index = index
    choice.body_text = choice.body_text or format_pack(choice.attr_pack)
  end
  return choices
end

local function apply_attr_pack_to_hero(hero, attr_pack, hero_attr_system)
  for attr_name, value in pairs(attr_pack) do
    if value ~= 0 then
      if hero_attr_system and hero_attr_system.add_attr then
        hero_attr_system.add_attr(hero, attr_name, value)
      elseif hero.add_attr then
        hero:add_attr(attr_name, value)
      end
    end
  end
  if hero_attr_system and hero_attr_system.rebuild_derived_attrs then
    hero_attr_system.rebuild_derived_attrs(hero)
  end
end

local function get_evolution_hero_entry(def)
  local unit_id = def and def.hero_unit_id or nil
  if unit_id == nil then
    return nil
  end
  return HERO_ROSTER_BY_UNIT_ID[unit_id]
end

local function get_evolution_display_name(def)
  local entry = get_evolution_hero_entry(def)
  if entry and entry.name and entry.name ~= '' then
    return entry.name
  end
  if def and def.name and def.name ~= '' then
    return def.name
  end
  return '未命名真身'
end

local function get_evolution_display_role(def)
  local entry = get_evolution_hero_entry(def)
  if entry and entry.title and entry.title ~= '' then
    return entry.title
  end
  return '英雄真身'
end

local function get_evolution_skill_name(def)
  local entry = get_evolution_hero_entry(def)
  if entry and entry.talent_skill and entry.talent_skill ~= '' then
    return entry.talent_skill
  end
  return nil
end

local function get_evolution_display_summary(def)
  local entry = get_evolution_hero_entry(def)
  if entry and entry.summary and entry.summary ~= '' then
    return entry.summary
  end
  return def and def.summary or ''
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

local env
local STATE = env and env.STATE or _G.STATE
  local message = _G.message
  local hero_attr_system = _G.hero_attr_system
  local hero_model = _G.hero_model

  local api = {
    EVOLUTION_DEFS = EVOLUTION_DEFS,
  }

  -- === 属性选择(attr_choice)系统 ===

  local function attr_ensure_runtime()
    STATE.attr_choice_runtime = STATE.attr_choice_runtime or {
      awaiting_choice = false,
      current_choices = nil,
      current_round = nil,
      diamond_count = 0,
      next_round_id = 1,
      applied_packs = {},
    }
    local runtime = STATE.attr_choice_runtime
    runtime.diamond_count = runtime.diamond_count or 0
    runtime.next_round_id = runtime.next_round_id or 1
    runtime.applied_packs = runtime.applied_packs or {}
    return runtime
  end

  local function open_round(level)
    local runtime = attr_ensure_runtime()
    runtime.awaiting_choice = true
    runtime.current_choices = build_choices(level)
    runtime.current_round = {
      round_id = runtime.next_round_id,
      level = math.max(1, tonumber(level) or 1),
      choice_count = CHOICE_COUNT,
    }
    runtime.next_round_id = runtime.next_round_id + 1
    return runtime
  end

  function api.ensure_runtime()
    return attr_ensure_runtime()
  end

  function api.grant_diamond(count, level)
    local runtime = attr_ensure_runtime()
    local add_count = math.max(1, math.floor(tonumber(count) or 1))
    runtime.diamond_count = (runtime.diamond_count or 0) + add_count
    runtime.last_grant_level = level
    message(string.format('获得属性钻石 x%d。', add_count))
    return runtime
  end

  function api.use_diamond()
    local runtime = attr_ensure_runtime()
    if runtime.awaiting_choice == true then
      return false
    end
    if (runtime.diamond_count or 0) <= 0 then
      message('当前没有可使用的属性钻石。')
      return false
    end
    runtime.diamond_count = runtime.diamond_count - 1
    local level = STATE.hero_progress and STATE.hero_progress.level or runtime.last_grant_level or 1
    open_round(level)
    return true
  end

  function api.get_pending_choice_kind()
    local runtime = STATE and STATE.attr_choice_runtime or nil
    if runtime and runtime.awaiting_choice == true and runtime.current_choices and #runtime.current_choices > 0 then
      return 'attr'
    end
    return nil
  end

  function api.apply_choice(index)
    local runtime = attr_ensure_runtime()
    if runtime.awaiting_choice ~= true or not runtime.current_choices then
      return false
    end

    local choice_index = math.max(1, math.floor(tonumber(index) or 1))
    local choice = runtime.current_choices[choice_index]
    if not choice then
      return false
    end

    local hero = STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      apply_attr_pack_to_hero(hero, choice.attr_pack or {}, hero_attr_system)
    end

    runtime.applied_packs[#runtime.applied_packs + 1] = copy_pack(choice.attr_pack)
    runtime.awaiting_choice = false
    runtime.current_choices = nil
    runtime.current_round = nil

    message(string.format('属性成长选择：%s。', tostring(choice.title_text or '属性')))

    return true
  end

  function api.has_pending_choice()
    return api.get_pending_choice_kind() == 'attr'
  end

  -- === 英雄进化 / 奖励队列系统 ===

  function api.create_evolution_runtime()
    local runtime = {
      owned_evolution_ids = {},
      ordered_evolution_ids = {},
      active_form_unit_id = nil,
      active_form_model_id = nil,
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
    return runtime
  end

  function api.get_evolution_runtime()
    local runtime = STATE.evolution_runtime
    if not runtime then
      runtime = api.create_evolution_runtime()
    end
    runtime.owned_evolution_ids = runtime.owned_evolution_ids or {}
    runtime.ordered_evolution_ids = runtime.ordered_evolution_ids or {}
    runtime.active_form_model_id = runtime.active_form_model_id or nil
    STATE.evolution_runtime = runtime
    return runtime
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

  function api.get_evolution_quality_label(quality)
    return EVOLUTION_QUALITY_LABELS[quality] or '普通'
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

  function api.get_evolution_active_count()
    local runtime = api.get_evolution_runtime()
    return #runtime.ordered_evolution_ids
  end

  local function build_evolution_choice_text(index, def)
    local skill_name = get_evolution_skill_name(def)
    local name_text = get_evolution_display_name(def)
    local role_text = get_evolution_display_role(def)
    local summary_text = get_evolution_display_summary(def)
    if skill_name and skill_name ~= '' then
      summary_text = string.format('神通「%s」：%s', skill_name, summary_text)
    end
    return string.format(
      '%d. [%s] %s·%s：%s',
      index,
      api.get_evolution_quality_label(def.quality),
      name_text,
      role_text,
      summary_text
    )
  end

  function api.build_evolution_slot_text(slot)
    local runtime = api.get_evolution_runtime()
    local evolution_id = runtime.ordered_evolution_ids[slot]
    if not evolution_id then
      return string.format('英雄进阶位 %d：空。', slot)
    end

    local def = EVOLUTION_DEFS[evolution_id]
    if not def then
      return string.format('英雄进阶位 %d：未知进阶 %s。', slot, tostring(evolution_id))
    end

    local skill_name = get_evolution_skill_name(def)
    local name_text = get_evolution_display_name(def)
    local role_text = get_evolution_display_role(def)
    return string.format(
      '英雄进阶位 %d：[%s] %s·%s%s',
      slot,
      api.get_evolution_quality_label(def.quality),
      name_text,
      role_text,
      skill_name and string.format('，神通「%s」', skill_name) or ''
    )
  end

  function api.show_evolution_loadout()
    message('英雄进阶栏：')
    local count = math.max(4, api.get_evolution_active_count())
    for slot = 1, count, 1 do
      message(api.build_evolution_slot_text(slot))
    end
  end

  local function build_available_evolution_defs(pool_rule, used_ids)
    local runtime = api.get_evolution_runtime()
    local result = {}

    for _, def in ipairs(EVOLUTION_DEF_LIST) do
      local excluded_by_owned = pool_rule and pool_rule.exclude_owned and runtime.owned_evolution_ids[def.id]
      local excluded_by_round = pool_rule and pool_rule.same_round_no_repeat and used_ids and used_ids[def.id]
      if not excluded_by_owned and not excluded_by_round then
        result[#result + 1] = def
      end
    end

    return result
  end

  local function get_evolution_pick_weight(def)
    return math.max(0.01, def.pool_weight or 1)
  end

  local function pick_weighted_evolution(pool)
    if #pool == 0 then
      return nil
    end

    local total_weight = 0
    local weights = {}
    for index, def in ipairs(pool) do
      local weight = get_evolution_pick_weight(def)
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

  local function build_evolution_defs_by_quality(pool_rule, used_ids)
    local available = build_available_evolution_defs(pool_rule, used_ids)
    local by_quality = {
      common = {},
      rare = {},
      epic = {},
    }

    for _, def in ipairs(available) do
      local quality = def.quality or 'common'
      by_quality[quality] = by_quality[quality] or {}
      by_quality[quality][#by_quality[quality] + 1] = def
    end

    return available, by_quality
  end

  local function roll_evolution_quality(pool_rule, allow_high_quality_only)
    local weights = {
      common = allow_high_quality_only and 0 or (pool_rule.common_weight or 0),
      rare = pool_rule.rare_weight or 0,
      epic = pool_rule.epic_weight or 0,
    }

    local total_weight = weights.common + weights.rare + weights.epic
    if total_weight <= 0 then
      if allow_high_quality_only then
        return 'rare'
      end
      return 'common'
    end

    local roll = math.random() * total_weight
    local passed = weights.common
    if roll <= passed then
      return 'common'
    end

    passed = passed + weights.rare
    if roll <= passed then
      return 'rare'
    end

    return 'epic'
  end

  local function pick_evolution_choices_for_rule(pool_rule_id, requested_choice_count)
    local pool_rule = EVOLUTION_POOL_RULES[pool_rule_id]
    assert(pool_rule and pool_rule.enabled, string.format('missing enabled evolution pool rule: %s', tostring(pool_rule_id)))

    local choice_count = requested_choice_count or pool_rule.choice_count or 2
    local choices = {}
    local used_ids = {}
    local has_high_quality = false

    while #choices < choice_count do
      local remaining_slots = choice_count - #choices
      local need_high_quality = pool_rule.guarantee_high_quality and not has_high_quality and remaining_slots == 1
      local available, by_quality = build_evolution_defs_by_quality(pool_rule, used_ids)
      if #available <= 0 then
        break
      end

      local target_quality = roll_evolution_quality(pool_rule, need_high_quality)
      local quality_pool = by_quality[target_quality] or {}

      if #quality_pool <= 0 then
        if need_high_quality then
          quality_pool = (#(by_quality.rare or {}) > 0 and by_quality.rare)
            or (#(by_quality.epic or {}) > 0 and by_quality.epic)
            or available
        else
          quality_pool = available
        end
      end

      local picked = pick_weighted_evolution(quality_pool)
      if not picked then
        break
      end

      choices[#choices + 1] = picked
      used_ids[picked.id] = true
      if picked.quality == 'rare' or picked.quality == 'epic' then
        has_high_quality = true
      end
    end

    return choices
  end

  function api.debug_pick_evolution_choices_for_rule(pool_rule_id, choice_count)
    return pick_evolution_choices_for_rule(pool_rule_id, choice_count)
  end

  local function apply_evolution_attack_skill_bonus(bonus, direction)
    if not bonus or not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
      return
    end

    local factor = direction or 1
    for skill_id, skill in pairs(STATE.attack_skill_state.by_id) do
      if skill_id ~= 'basic_attack' then
        if bonus.damage_ratio and bonus.damage_ratio ~= 0 then
          skill.damage_ratio = math.max(0, (skill.damage_ratio or 0) + bonus.damage_ratio * factor)
        end
        if bonus.repeat_count and bonus.repeat_count ~= 0 then
          skill.repeat_count = math.max(1, (skill.repeat_count or 1) + bonus.repeat_count * factor)
        end
        if bonus.range_bonus and bonus.range_bonus ~= 0 then
          skill.range_bonus = math.max(0, (skill.range_bonus or 0) + bonus.range_bonus * factor)
        end
        if bonus.cooldown_reduction and bonus.cooldown_reduction ~= 0 then
          skill.cooldown_reduction = math.max(0, (skill.cooldown_reduction or 0) + bonus.cooldown_reduction * factor)
        end
      end
    end
  end

  local function build_evolution_bonus_pack()
    local runtime = api.get_evolution_runtime()
    local aggregate = {
      attr = {},
      runtime = {},
      attack_skill = {},
    }

    for _, evolution_id in ipairs(runtime.ordered_evolution_ids) do
      local def = EVOLUTION_DEFS[evolution_id]
      if def and def.bonuses then
        add_bonus_pack(aggregate.attr, def.bonuses.attr)
        add_bonus_pack(aggregate.runtime, def.bonuses.runtime)
        add_bonus_pack(aggregate.attack_skill, def.bonuses.attack_skill)
      end
    end

    return aggregate
  end

  function api.sync_evolution_effects()
    local runtime = api.get_evolution_runtime()
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
      apply_attr_pack_to_hero(STATE.hero, negative_attr, hero_attr_system)
    end

    apply_evolution_attack_skill_bonus(previous.attack_skill or {}, -1)

    local aggregate = build_evolution_bonus_pack()

    if STATE.hero and STATE.hero:is_exist() then
      apply_attr_pack_to_hero(STATE.hero, aggregate.attr, hero_attr_system)
    end

    apply_evolution_attack_skill_bonus(aggregate.attack_skill or {}, 1)

    runtime.applied = aggregate
    if _G.sync_basic_attack_ability then _G.sync_basic_attack_ability() end
  end

  local function get_hero_hp_snapshot()
    if not STATE.hero or not STATE.hero:is_exist() then
      return nil
    end

    local current_hp = tonumber(STATE.hero:get_hp()) or 0
    local max_hp = hero_attr_system and hero_attr_system.get_attr(STATE.hero, '生命结算值') or 0
    if max_hp <= 0 then
      max_hp = tonumber(STATE.hero:get_attr('生命结算值'))
        or tonumber(STATE.hero:get_attr('生命'))
        or tonumber(STATE.hero:get_attr('hp_max'))
        or 0
    end

    return {
      hp = current_hp,
      max_hp = max_hp,
      hp_ratio = max_hp > 0 and math.max(0, math.min(1, current_hp / max_hp)) or nil,
    }
  end

  local function resolve_evolution_target_model_id(target_unit_id)
    if not target_unit_id or not y3 or not y3.unit or not y3.unit.get_model_by_key then
      return nil
    end

    local ok, model_id = pcall(y3.unit.get_model_by_key, target_unit_id)
    if not ok or model_id == nil or model_id == 0 then
      return nil
    end
    return model_id
  end

  local function restore_hero_hp_by_snapshot(snapshot)
    if not snapshot or not STATE.hero or not STATE.hero:is_exist() then
      return
    end

    local max_hp = hero_attr_system and hero_attr_system.get_attr(STATE.hero, '生命结算值') or 0
    if max_hp <= 0 then
      max_hp = tonumber(STATE.hero:get_attr('生命结算值'))
        or tonumber(STATE.hero:get_attr('生命'))
        or tonumber(STATE.hero:get_attr('hp_max'))
        or 0
    end
    if max_hp <= 0 then
      return
    end

    local target_hp = snapshot.hp_ratio and (max_hp * snapshot.hp_ratio) or snapshot.hp
    target_hp = math.max(1, math.min(max_hp, tonumber(target_hp) or max_hp))
    STATE.hero:set_hp(target_hp)
  end

  local function apply_evolution_hero_form(def)
    local hero = STATE.hero
    if not hero or not hero:is_exist() then
      return false
    end

    local target_unit_id = def and def.hero_unit_id
    if not target_unit_id then
      message(string.format(
        '警告：真身 %s 缺少英雄单位ID，已跳过形态替换。',
        tostring(get_evolution_display_name(def))
      ))
      return false
    end

    -- 优先使用 hero_model 模块（支持英雄库配置查找）
    if hero_model and hero_model.apply_evolution_model then
      local ok = hero_model.apply_evolution_model(hero, def)
      if not ok then
        message(string.format(
          '警告：真身 %s 替换英雄模型失败。',
          tostring(get_evolution_display_name(def))
        ))
      end
      return ok
    end

    -- 回退：直接使用单位键解析模型
    local target_model_id = resolve_evolution_target_model_id(target_unit_id)
    if not target_model_id then
      message(string.format(
        '警告：真身 %s 缺少英雄模型资源 %s，已跳过形态替换。',
        tostring(get_evolution_display_name(def)),
        tostring(target_unit_id)
      ))
      return false
    end

    local runtime = api.get_evolution_runtime()
    if runtime.active_form_model_id
      and runtime.active_form_model_id ~= target_model_id
      and hero.cancel_replace_model then
      pcall(hero.cancel_replace_model, hero, runtime.active_form_model_id)
    end

    local ok, err = pcall(function()
      hero:replace_model(target_model_id)
    end)
    if not ok then
      message(string.format(
        '警告：真身 %s 替换英雄模型失败：%s',
        tostring(get_evolution_display_name(def)),
        tostring(err)
      ))
      return false
    end

    runtime.active_form_unit_id = target_unit_id
    runtime.active_form_model_id = target_model_id
    return true
  end

  local function try_process_reward_queue()
    if STATE.game_finished then
      return false
    end
    local evolution_runtime = api.get_evolution_runtime()
    if evolution_runtime.awaiting_choice then
      return false
    end
    if STATE.gear_state and STATE.gear_state.awaiting_choice then
      return false
    end
    if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice then
      return false
    end
    if STATE.attr_choice_runtime
        and STATE.attr_choice_runtime.awaiting_choice
        and STATE.attr_choice_runtime.current_choices then
      return false
    end

    local queue = api.get_reward_queue()
    local next_entry = table.remove(queue, 1)
    if not next_entry then
      return false
    end

    if next_entry.kind == 'evolution_choice' then
      local round = next_entry.round_id and evolution_runtime.rounds_by_id[next_entry.round_id] or nil
      if not round then
        message('英雄进阶轮次数据不存在，本次奖励已跳过。')
        return true
      end

      local choices = {}
      for _, evolution_id in ipairs(round.candidate_evolution_ids or {}) do
        local def = EVOLUTION_DEFS[evolution_id]
        if def and not evolution_runtime.owned_evolution_ids[evolution_id] then
          choices[#choices + 1] = def
        end
      end

      if #choices == 0 then
        message(string.format('%s：没有可用英雄进阶候选，本轮已跳过。', round.ui_title or '英雄进阶选择'))
        round.state = 'skipped'
        return true
      end

      evolution_runtime.current_round = round
      evolution_runtime.current_choices = choices
      evolution_runtime.awaiting_choice = true
      round.state = 'pending'
      STATE.choice_panel_hidden = false

      round.choice_count = #choices
      message(string.format('%s：获得一次英雄真身 %d选1。', round.ui_title or '英雄进阶', #choices))
      api.show_evolution_choices()
      return true
    end

    message(string.format('存在未识别的奖励队列类型：%s。', tostring(next_entry.kind)))
    return true
  end

  local function resolve_evolution_pick(def)
    local runtime = api.get_evolution_runtime()
    local hero_snapshot = get_hero_hp_snapshot()
    runtime.owned_evolution_ids[def.id] = true
    runtime.ordered_evolution_ids[#runtime.ordered_evolution_ids + 1] = def.id

    if runtime.current_round then
      runtime.current_round.selected_evolution_id = def.id
      runtime.current_round.state = 'resolved'
    end

    runtime.awaiting_choice = false
    runtime.current_choices = nil
    runtime.current_round = nil
    STATE.choice_panel_hidden = true

    apply_evolution_hero_form(def)
    api.sync_evolution_effects()
    restore_hero_hp_by_snapshot(hero_snapshot)

    local skill_name = get_evolution_skill_name(def)
    message(string.format(
      '已完成英雄进阶：[%s] %s·%s%s。',
      api.get_evolution_quality_label(def.quality),
      get_evolution_display_name(def),
      get_evolution_display_role(def),
      skill_name and string.format('，神通「%s」已激活', skill_name) or ''
    ))
    api.show_evolution_loadout()

    try_process_reward_queue()
  end

  function api.show_evolution_choices()
    local runtime = api.get_evolution_runtime()
    if not runtime.awaiting_choice or not runtime.current_choices then
      return
    end

    STATE.choice_panel_hidden = false
    local title = runtime.current_round and runtime.current_round.ui_title or '英雄进阶'
    message(string.format(
      '%s：请点击面板完成选择。',
      title
    ))
    for index, def in ipairs(runtime.current_choices) do
      message(build_evolution_choice_text(index, def))
    end
    api.show_evolution_loadout()
  end

  function api.apply_evolution_choice(index)
    local runtime = api.get_evolution_runtime()
    if not runtime.awaiting_choice or not runtime.current_choices then
      return
    end

    local def = runtime.current_choices[index]
    if not def then
      return
    end

    resolve_evolution_pick(def)
  end

  function api.try_process_reward_queue()
    return try_process_reward_queue()
  end

  function api.try_queue_evolution_node_for_level(level)
    local node = EVOLUTION_NODES_BY_LEVEL[level]
    if not node then
      return false
    end

    local runtime = api.get_evolution_runtime()
    if runtime.triggered_node_ids[node.id] then
      return false
    end

    runtime.triggered_node_ids[node.id] = true

    local choices = pick_evolution_choices_for_rule(node.pool_rule_id, node.choice_count or 2)
    if #choices == 0 then
      message(string.format('%s：本局没有可用英雄候选。', node.ui_title or '英雄进阶'))
      return false
    end

    local round_id = runtime.next_round_id
    runtime.next_round_id = runtime.next_round_id + 1
    runtime.rounds_by_id[round_id] = {
      round_id = round_id,
      node_id = node.id,
      trigger_level = node.trigger_level,
      ui_title = node.ui_title,
      choice_count = #choices,
      state = 'queued',
      candidate_evolution_ids = {},
    }

    for _, def in ipairs(choices) do
      runtime.rounds_by_id[round_id].candidate_evolution_ids[#runtime.rounds_by_id[round_id].candidate_evolution_ids + 1] = def.id
    end

    enqueue_reward_entry({
      kind = 'evolution_choice',
      priority = node.queue_priority or 95,
      round_id = round_id,
      source_name = node.ui_title or '英雄进阶',
    })

    if runtime.awaiting_choice then
      message(string.format('%s 已加入待处理奖励队列。', node.ui_title or '英雄进阶'))
      return true
    end

    if not try_process_reward_queue() and api.get_reward_queue_count() > 0 then
      message(string.format('%s 已加入待处理奖励队列。', node.ui_title or '英雄进阶'))
    end

    return true
  end

  function api.handle_hero_be_hurt()
  end

  _G.reward_system = api

return M
