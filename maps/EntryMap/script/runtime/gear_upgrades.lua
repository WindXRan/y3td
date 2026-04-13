local M = {}
local DefaultConfig = require 'data.object_tables.gear_upgrade_config'

local SLOT_ORDER = { 'weapon' }
local SLOT_LABELS = {
  weapon = '成长武器',
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
  runtime.items[slot] = runtime.items[slot] or {
    slot = slot,
    level = 1,
    affixes = {},
  }
  return runtime.items[slot]
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

return M
