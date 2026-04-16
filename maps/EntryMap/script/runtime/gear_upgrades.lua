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

local function get_config(config)
  return config or DefaultConfig
end

local function get_slot_config(slot, config)
  return get_config(config).slots and get_config(config).slots[slot] or nil
end

local function get_level_config(level, config)
  return get_config(config).levels_by_level and get_config(config).levels_by_level[level] or nil
end

local function make_affix_choices(slot, level)
  local slot_label = SLOT_LABELS[slot] or tostring(slot)
  local slot_cfg = get_slot_config(slot)
  local choice_count = slot_cfg and slot_cfg.affix_choice_count or CHOICE_COUNT
  if choice_count < 1 then
    choice_count = CHOICE_COUNT
  end
  local choices = {
    {
      id = slot .. '_affix_' .. tostring(level) .. '_1',
      display_name = slot_label .. '锋芒',
      summary = '攻击向词缀',
    },
    {
      id = slot .. '_affix_' .. tostring(level) .. '_2',
      display_name = slot_label .. '专注',
      summary = '功能向词缀',
    },
    {
      id = slot .. '_affix_' .. tostring(level) .. '_3',
      display_name = slot_label .. '底蕴',
      summary = '成长向词缀',
    },
  }
  while #choices > choice_count do
    choices[#choices] = nil
  end
  return choices
end

local function get_max_level(slot, config)
  local slot_cfg = get_slot_config(slot, config)
  if slot_cfg and slot_cfg.max_level and slot_cfg.max_level > 0 then
    return slot_cfg.max_level
  end
  return MAX_LEVEL
end

local function is_affix_node(level, config)
  local level_cfg = get_level_config(level, config)
  if level_cfg ~= nil then
    return level_cfg.is_affix_node == true
  end
  return level % AFFIX_NODE_INTERVAL == 0
end

local function ensure_item(runtime, slot)
  local slot_cfg = runtime.config and runtime.config.slots and runtime.config.slots[slot] or nil
  runtime.items[slot] = runtime.items[slot] or {
    slot = slot,
    level = 1,
    affixes = {},
    item_key = slot_cfg and slot_cfg.item_key or nil,
  }
  if runtime.items[slot].item_key == nil and slot_cfg and slot_cfg.item_key ~= nil then
    runtime.items[slot].item_key = slot_cfg.item_key
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
  local lines = {}
  for _, affix in ipairs(item.affixes or {}) do
    local display_name = affix.display_name or affix.id
    if display_name then
      lines[#lines + 1] = tostring(display_name)
    end
  end
  if #lines == 0 then
    return { '暂无词缀' }
  end
  return lines
end

function M.ensure_runtime(state, config)
  state.gear_state = state.gear_state or {
    items = {},
    awaiting_choice = false,
    current_choices = nil,
    pending_affix_choice = nil,
  }

  local runtime = state.gear_state
  runtime.config = get_config(config)
  runtime.items = runtime.items or {}
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
  local level_cfg = get_level_config(current_level, config)
  if level_cfg then
    return level_cfg.gold_cost
  end
  local band_index = math.floor(math.max(0, current_level - 1) / 10)
  return 100 + band_index * 50
end

local function queue_affix_choice(runtime, slot, level)
  runtime.awaiting_choice = true
  runtime.pending_affix_choice = {
    slot = slot,
    level = level,
  }
  runtime.current_choices = make_affix_choices(slot, level)
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

    if is_affix_node(item.level, runtime.config) then
      queue_affix_choice(runtime, slot, item.level)
      return item.level
    end
  end

  return item.level
end

function M.apply_affix_choice(env, choice_index)
  local state = assert(env and env.STATE, 'STATE is required')
  local config = env and env.CONFIG and env.CONFIG.gear_upgrade_config or nil
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
  }

  runtime.awaiting_choice = false
  runtime.current_choices = nil
  runtime.pending_affix_choice = nil
  return true
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
