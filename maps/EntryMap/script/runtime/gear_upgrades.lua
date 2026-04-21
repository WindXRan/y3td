local M = {}
local DefaultConfig = require 'data.object_tables.gear_upgrade_config'

local SLOT_ORDER = { 'weapon' }
local SLOT_LABELS = {
  weapon = '成长武器',
}
local DIRECT_ATTR_KEYS = {
  ['物理攻击'] = { is_percent = false },
  ['法术攻击'] = { is_percent = false },
  ['攻击速度'] = { is_percent = true },
  ['暴击率'] = { is_percent = true },
  ['暴击伤害'] = { is_percent = true },
  ['生命值'] = { is_percent = false },
  ['生命恢复'] = { is_percent = false },
  ['护甲'] = { is_percent = false },
  ['魔法抗性'] = { is_percent = false },
  ['移动速度'] = { is_percent = false },
}

local MAX_LEVEL = 100
local AFFIX_NODE_INTERVAL = 10
local CHOICE_COUNT = 3
local QUALITY_ORDER = { 'common', 'rare', 'epic' }
local QUALITY_LABELS = {
  common = '普通',
  rare = '稀有',
  epic = '史诗',
}

local function get_config(config)
  return config or DefaultConfig
end

local function clone_bonus_pack(pack)
  local result = {}
  for attr_name, value in pairs(pack or {}) do
    if value ~= 0 then
      result[attr_name] = value
    end
  end
  return result
end

local function add_bonus_pack(target, pack)
  for attr_name, value in pairs(pack or {}) do
    local number = tonumber(value) or 0
    if number ~= 0 then
      target[attr_name] = (target[attr_name] or 0) + number
    end
  end
  return target
end

local function get_slot_config(slot, config)
  local resolved = get_config(config)
  return resolved.slots and resolved.slots[slot] or nil
end

local function get_slot_weapon_id(slot, config)
  local slot_cfg = get_slot_config(slot, config)
  if slot_cfg and slot_cfg.weapon_id and slot_cfg.weapon_id ~= '' then
    return slot_cfg.weapon_id
  end
  return slot
end

local function get_level_config(slot, level, config, weapon_id)
  local resolved = get_config(config)
  local final_weapon_id = weapon_id or get_slot_weapon_id(slot, resolved)
  if resolved.levels_by_weapon and resolved.levels_by_weapon[final_weapon_id] then
    return resolved.levels_by_weapon[final_weapon_id][level] or nil
  end
  if resolved.levels_by_level then
    return resolved.levels_by_level[level] or nil
  end
  return nil
end

local function get_affix_pool(pool_id, config)
  if not pool_id then
    return {}
  end
  local resolved = get_config(config)
  if resolved.affixes_by_pool and resolved.affixes_by_pool[pool_id] then
    return resolved.affixes_by_pool[pool_id]
  end
  return {}
end

local function get_max_level(slot, config)
  local slot_cfg = get_slot_config(slot, config)
  if slot_cfg and slot_cfg.max_level and slot_cfg.max_level > 0 then
    return slot_cfg.max_level
  end
  return MAX_LEVEL
end

local function is_affix_node(slot, level, config, weapon_id)
  local level_cfg = get_level_config(slot, level, config, weapon_id)
  if level_cfg ~= nil then
    return level_cfg.is_affix_node == true
  end
  return level % AFFIX_NODE_INTERVAL == 0
end

local function ensure_item(runtime, slot)
  local slot_cfg = runtime.config and runtime.config.slots and runtime.config.slots[slot] or nil
  local init_level = slot_cfg and tonumber(slot_cfg.init_level) or 1
  runtime.items[slot] = runtime.items[slot] or {
    slot = slot,
    level = math.max(1, init_level or 1),
    affixes = {},
    item_key = slot_cfg and slot_cfg.item_key or nil,
    weapon_id = slot_cfg and slot_cfg.weapon_id or slot,
  }
  runtime.items[slot].level = math.max(1, tonumber(runtime.items[slot].level) or init_level or 1)
  runtime.items[slot].affixes = runtime.items[slot].affixes or {}
  if runtime.items[slot].item_key == nil and slot_cfg and slot_cfg.item_key ~= nil then
    runtime.items[slot].item_key = slot_cfg.item_key
  end
  if (runtime.items[slot].weapon_id == nil or runtime.items[slot].weapon_id == '')
    and slot_cfg
    and slot_cfg.weapon_id ~= nil then
    runtime.items[slot].weapon_id = slot_cfg.weapon_id
  end
  return runtime.items[slot]
end

local function format_number(value)
  if math.type and math.type(value) == 'integer' then
    return tostring(value)
  end
  if value == math.floor(value) then
    return tostring(math.floor(value))
  end
  return string.format('%.2f', value):gsub('0+$', ''):gsub('%.+$', '')
end

local function format_attr_value(value, attr_cfg)
  if attr_cfg and attr_cfg.is_percent then
    return string.format('%s%%', format_number(value * 100))
  end
  return format_number(value)
end

local function build_attr_lines(item_key, item_api)
  if not item_key or not item_api or not item_api.attr_pick_by_key or not item_api.get_attribute_by_key then
    return { '当前无直接属性增幅' }
  end

  local picked = item_api.attr_pick_by_key(item_key) or {}
  local lines = {}
  for _, key in ipairs(picked) do
    local attr_cfg = DIRECT_ATTR_KEYS[key]
    if attr_cfg then
      local value = tonumber(item_api.get_attribute_by_key(item_key, key)) or 0
      if value ~= 0 then
        lines[#lines + 1] = string.format('%s +%s', key, format_attr_value(value, attr_cfg))
      end
    end
  end

  if #lines == 0 then
    return { '当前无直接属性增幅' }
  end
  return lines
end

local function build_affix_lines(item)
  local names = {}
  for _, affix in ipairs(item.affixes or {}) do
    local display_name = affix.display_name or affix.id
    local quality_label = QUALITY_LABELS[affix.quality]
    if quality_label and display_name then
      display_name = string.format('[%s] %s', quality_label, display_name)
    end
    if display_name then
      names[#names + 1] = tostring(display_name)
    end
    if #names >= 3 then
      break
    end
  end

  if #names == 0 then
    return {
      {
        title = '当前词缀',
        body = '暂无词缀',
      },
    }
  end

  local lines = {}
  for index, name in ipairs(names) do
    lines[#lines + 1] = {
      title = index == 1 and '当前词缀' or string.format('词缀%d', index),
      body = name,
    }
  end
  return lines
end

local function item_has_blocking_affix(item, affix_def)
  if not affix_def then
    return false
  end
  local unique_group = affix_def.unique_group
  local is_unique = affix_def.is_unique == true
  if not unique_group and not is_unique then
    return false
  end

  for _, owned in ipairs(item.affixes or {}) do
    if owned.id == affix_def.affix_id then
      return true
    end
    if unique_group and owned.unique_group == unique_group then
      return true
    end
    if is_unique and owned.id == affix_def.affix_id then
      return true
    end
  end
  return false
end

local function build_affix_choice(affix_def, level)
  return {
    id = affix_def.affix_id,
    affix_id = affix_def.affix_id,
    level = level,
    display_name = affix_def.display_name,
    summary = affix_def.summary,
    bonus_pack = clone_bonus_pack(affix_def.bonus_pack),
    quality = affix_def.quality or 'common',
    unique_group = affix_def.unique_group,
    is_unique = affix_def.is_unique == true,
  }
end

local function make_fallback_affix_choices(slot, level, choice_count)
  local slot_label = SLOT_LABELS[slot] or tostring(slot)
  local choices = {
    {
      id = slot .. '_affix_' .. tostring(level) .. '_1',
      display_name = slot_label .. '锋芒',
      summary = '攻击向词缀',
      bonus_pack = {},
    },
    {
      id = slot .. '_affix_' .. tostring(level) .. '_2',
      display_name = slot_label .. '专注',
      summary = '功能向词缀',
      bonus_pack = {},
    },
    {
      id = slot .. '_affix_' .. tostring(level) .. '_3',
      display_name = slot_label .. '底蕴',
      summary = '成长向词缀',
      bonus_pack = {},
    },
  }
  while #choices > choice_count do
    choices[#choices] = nil
  end
  return choices
end

local function make_affix_choices(slot, item, level, config)
  local slot_cfg = get_slot_config(slot, config)
  local choice_count = slot_cfg and slot_cfg.affix_choice_count or CHOICE_COUNT
  if choice_count < 1 then
    choice_count = CHOICE_COUNT
  end

  local level_cfg = get_level_config(slot, level, config, item and item.weapon_id or nil)
  local pool = get_affix_pool(level_cfg and level_cfg.affix_pool_id or nil, config)
  local choices = {}
  local buckets = {}
  local eligible = {}

  local function append_choice(candidate)
    if not candidate or candidate.id == nil then
      return
    end
    for _, existing in ipairs(choices) do
      if existing.id == candidate.id then
        return
      end
    end
    choices[#choices + 1] = candidate
  end

  for _, affix_def in ipairs(pool) do
    if not item_has_blocking_affix(item, affix_def) then
      local choice = build_affix_choice(affix_def, level)
      local quality = affix_def.quality or 'common'
      buckets[quality] = buckets[quality] or {}
      buckets[quality][#buckets[quality] + 1] = choice
      eligible[#eligible + 1] = choice
    end
  end

  for _, quality in ipairs(QUALITY_ORDER) do
    append_choice(buckets[quality] and buckets[quality][1] or nil)
    if #choices >= choice_count then
      break
    end
  end

  if #choices < choice_count then
    for _, choice in ipairs(eligible) do
      append_choice(choice)
      if #choices >= choice_count then
        break
      end
    end
  end

  if #choices == 0 then
    return make_fallback_affix_choices(slot, level, choice_count)
  end

  return choices
end

local function queue_affix_choice(runtime, slot, level)
  local item = ensure_item(runtime, slot)
  runtime.awaiting_choice = true
  runtime.pending_affix_choice = {
    slot = slot,
    level = level,
    weapon_id = item.weapon_id,
  }
  runtime.current_choices = make_affix_choices(slot, item, level, runtime.config)
end

local function compute_item_bonus(item, config)
  local total = {}
  local current_level = tonumber(item and item.level) or 1

  for level = 1, math.max(1, current_level) - 1, 1 do
    local level_cfg = get_level_config(item.slot, level, config, item.weapon_id)
    if level_cfg and level_cfg.bonus_pack then
      add_bonus_pack(total, level_cfg.bonus_pack)
    end
  end

  for _, affix in ipairs(item.affixes or {}) do
    add_bonus_pack(total, affix.bonus_pack)
  end

  return total
end

local function apply_bonus_diff(hero, hero_attr_system, previous_bonus, next_bonus)
  local changed = false
  local seen = {}

  for attr_name, value in pairs(next_bonus or {}) do
    local number = tonumber(value) or 0
    seen[attr_name] = true
    local previous = tonumber(previous_bonus and previous_bonus[attr_name]) or 0
    local delta = number - previous
    if delta ~= 0 then
      hero_attr_system.add_attr(hero, attr_name, delta)
      changed = true
    end
  end

  for attr_name, previous in pairs(previous_bonus or {}) do
    if not seen[attr_name] and previous ~= 0 then
      hero_attr_system.add_attr(hero, attr_name, -previous)
      changed = true
    end
  end

  return changed
end

function M.ensure_runtime(state, config)
  state.gear_state = state.gear_state or {
    items = {},
    awaiting_choice = false,
    current_choices = nil,
    pending_affix_choice = nil,
    applied_attr_bonuses = {},
  }

  local runtime = state.gear_state
  runtime.config = get_config(config)
  runtime.items = runtime.items or {}
  runtime.applied_attr_bonuses = runtime.applied_attr_bonuses or {}
  for _, slot in ipairs(SLOT_ORDER) do
    ensure_item(runtime, slot)
  end

  return runtime
end

function M.get_pending_choice_kind(state)
  local runtime = state and state.gear_state or nil
  if runtime and runtime.awaiting_choice == true then
    return 'gear'
  end
  return nil
end

function M.get_upgrade_cost(slot, current_level, config)
  if not slot or current_level == nil then
    return nil
  end
  if current_level >= get_max_level(slot, config) then
    return 0
  end
  local level_cfg = get_level_config(slot, current_level, config)
  if level_cfg then
    return level_cfg.gold_cost
  end
  local band_index = math.floor(math.max(0, current_level - 1) / 10)
  return 100 + band_index * 50
end

function M.try_upgrade_levels(env, slot, count)
  local state = assert(env and env.STATE, 'STATE is required')
  local config = env and env.CONFIG and env.CONFIG.gear_upgrade_config or nil
  local runtime = M.ensure_runtime(state, config)
  local item = ensure_item(runtime, slot)
  local resources = state.resources or {}
  local tries = math.max(1, math.floor(tonumber(count) or 1))

  if runtime.awaiting_choice == true then
    return item.level
  end

  for _ = 1, tries do
    if item.level >= get_max_level(slot, runtime.config) then
      return item.level
    end

    local cost = M.get_upgrade_cost(slot, item.level, runtime.config) or 0
    if (resources.gold or 0) < cost then
      return item.level
    end

    resources.gold = (resources.gold or 0) - cost
    item.level = item.level + 1

    if is_affix_node(slot, item.level, runtime.config, item.weapon_id) then
      queue_affix_choice(runtime, slot, item.level)
      return item.level
    end
  end

  return item.level
end

function M.apply_affix_choice(env, choice_index)
  local state = assert(env and env.STATE, 'STATE is required')
  local config = env and env.CONFIG and env.CONFIG.gear_upgrade_config or nil
  local message = env and env.message or function() end
  local runtime = M.ensure_runtime(state, config)
  local pending = runtime.pending_affix_choice

  if runtime.awaiting_choice ~= true or not pending then
    return false
  end

  local index = math.max(1, math.floor(tonumber(choice_index) or 1))
  local choice = runtime.current_choices and runtime.current_choices[index] or nil
  if not choice then
    return false
  end

  local item = ensure_item(runtime, pending.slot)
  item.affixes[#item.affixes + 1] = {
    id = choice.id,
    level = pending.level,
    display_name = choice.display_name,
    summary = choice.summary,
    bonus_pack = clone_bonus_pack(choice.bonus_pack),
    quality = choice.quality or 'common',
    unique_group = choice.unique_group,
    is_unique = choice.is_unique == true,
  }

  local quality_label = QUALITY_LABELS[choice.quality or 'common'] or '普通'
  local display_name = choice.display_name or choice.id or '未命名词条'
  runtime.awaiting_choice = false
  runtime.current_choices = nil
  runtime.pending_affix_choice = nil
  message(string.format('成长武器获得 [%s] 词条：%s。', quality_label, tostring(display_name)))
  return true
end

function M.sync_runtime_bonuses(state, hero, config, hero_attr_system)
  if not state or not hero or not hero_attr_system or not hero_attr_system.add_attr then
    return false
  end

  local runtime = M.ensure_runtime(state, config)
  local changed = false

  for _, slot in ipairs(SLOT_ORDER) do
    local item = ensure_item(runtime, slot)
    local next_bonus = compute_item_bonus(item, runtime.config)
    local previous_bonus = runtime.applied_attr_bonuses[slot] or {}
    if apply_bonus_diff(hero, hero_attr_system, previous_bonus, next_bonus) then
      changed = true
    end
    runtime.applied_attr_bonuses[slot] = clone_bonus_pack(next_bonus)
  end

  if changed and hero_attr_system.rebuild_derived_attrs then
    hero_attr_system.rebuild_derived_attrs(hero)
  end

  return changed
end

function M.build_slot_text(state, slot)
  local runtime = M.ensure_runtime(state)
  local item = ensure_item(runtime, slot)
  local label = SLOT_LABELS[slot] or tostring(slot)
  local max_level = get_max_level(slot, runtime.config)
  local next_cost = M.get_upgrade_cost(slot, item.level, runtime.config) or 0
  return string.format(
    '%s Lv.%d / %d  词缀 %d  下级花费 %d',
    label,
    item.level,
    max_level,
    #item.affixes,
    next_cost
  )
end

function M.build_tip_payload(state, slot, config, item_api)
  local runtime = M.ensure_runtime(state, config)
  local item = ensure_item(runtime, slot)
  local slot_cfg = get_slot_config(slot, runtime.config)
  local item_key = item.item_key or slot_cfg and slot_cfg.item_key or nil
  local cost = M.get_upgrade_cost(slot, item.level, runtime.config) or 0
  local name = item_key and item_api and item_api.get_name_by_key and item_api.get_name_by_key(item_key) or nil
  local icon_res = item_key and item_api and item_api.get_icon_id_by_key and item_api.get_icon_id_by_key(item_key) or nil

  return {
    title_text = name or (SLOT_LABELS[slot] or tostring(slot)),
    subtitle_text = string.format('%s Lv.%d', SLOT_LABELS[slot] or tostring(slot), item.level),
    cost_text = cost > 0 and string.format('升级所需：%d 金币', cost) or '升级所需：已满级',
    icon_res = icon_res,
    attr_lines = build_attr_lines(item_key, item_api),
    affix_lines = build_affix_lines(item),
  }
end

function M.sync_items_to_hero(state, hero, config)
  if not state or not hero then
    return false
  end

  local runtime = M.ensure_runtime(state, config)
  local synced = false

  for _, slot in ipairs(SLOT_ORDER) do
    local item = ensure_item(runtime, slot)
    local slot_cfg = get_slot_config(slot, runtime.config)
    local item_key = item.item_key or slot_cfg and slot_cfg.item_key or nil

    if item_key ~= nil then
      if hero.get_bar_cnt and hero.set_bar_cnt then
        local bar_cnt = tonumber(hero:get_bar_cnt()) or 0
        if bar_cnt < 1 then
          hero:set_bar_cnt(1)
        end
      end

      local has_item = hero.has_item_by_key and hero:has_item_by_key(item_key) or false
      if not has_item and hero.add_item then
        hero:add_item(item_key, '物品栏')
        synced = true
      end
    end
  end

  return synced
end

return M
