local M = {}

local BondNodes = require 'runtime.bond_nodes'
local BondTipModelBuilder = require 'runtime.bond_tip_model_builder'
local BondTemplates = require 'runtime.bond_templates.init'
local BondDrawConfig = require 'data.object_tables.bond_draw_config'
local BondMiscConfig = require 'data.object_tables.bond_misc_config'
local BondPickConfig = require 'data.object_tables.bond_pick_config'
local BondRootSets = require 'data.object_tables.bond_root_sets'

local NODE_LIST = BondNodes.list
local NODE_BY_ID = BondNodes.by_id
local LINE_BY_ID = BondNodes.by_line
local ROOT_NODE_IDS = BondNodes.root_ids
local ROOT_NODE_ID_SET = {}
local ROOT_SUBTREE_NODE_IDS = {}
local ROOT_SET_PROGRESS_NODE_IDS = {}
local ROOT_STAGE_NODE_IDS = {}
local ROOT_STAGE_TIERS = {}

local BOND_DRAW_COST = BondDrawConfig.draw_cost or 100
local SYSTEM_DYNAMIC_NODE_ID = '__system__'

local PER_SECOND_ATTR_KEYS = BondMiscConfig.per_second_attr_keys or {}
local GROUP_LABELS = BondMiscConfig.group_labels or {}

local ROOT_SET_DOC_META = BondRootSets.by_id or {}

local is_root_set_complete
local is_group_started

local GROUP_CHOICE_ORDER = BondDrawConfig.group_choice_order or {
  'body',
  'economy',
  'magic',
  'archery',
  'critical',
  'growth',
}

local GROUP_ROOT_IDS_BY_GROUP = {}
local GROUP_CHOICE_DEFS = BondDrawConfig.group_choice_defs or {
  body = {
    id = '__group_body',
    group_id = 'body',
    display_name = '体术',
    quality = 'rare',
    desc = '解锁：生命、战术、固守分支',
  },
  economy = {
    id = '__group_economy',
    group_id = 'economy',
    display_name = '经济',
    quality = 'rare',
    desc = '解锁：贪婪、挑战分支',
  },
  magic = {
    id = '__group_magic',
    group_id = 'magic',
    display_name = '法术',
    quality = 'rare',
    desc = '解锁：魔法师、魔能、魔术、急速、元素师分支',
  },
  archery = {
    id = '__group_archery',
    group_id = 'archery',
    display_name = '箭术',
    quality = 'rare',
    desc = '解锁：广射、速攻、射术分支',
  },
  critical = {
    id = '__group_critical',
    group_id = 'critical',
    display_name = '暴击',
    quality = 'rare',
    desc = '解锁：致命、大炮分支',
  },
  growth = {
    id = '__group_growth',
    group_id = 'growth',
    display_name = '成长',
    quality = 'rare',
    desc = '解锁：敏捷、力量、智力分支',
  },
}

for _, node_id in ipairs(ROOT_NODE_IDS) do
  ROOT_NODE_ID_SET[node_id] = true
  local node_def = NODE_BY_ID[node_id]
  if node_def and node_def.group_id then
    GROUP_ROOT_IDS_BY_GROUP[node_def.group_id] = GROUP_ROOT_IDS_BY_GROUP[node_def.group_id] or {}
    GROUP_ROOT_IDS_BY_GROUP[node_def.group_id][#GROUP_ROOT_IDS_BY_GROUP[node_def.group_id] + 1] = node_id
    if GROUP_CHOICE_DEFS[node_def.group_id] and not GROUP_CHOICE_DEFS[node_def.group_id].icon then
      GROUP_CHOICE_DEFS[node_def.group_id].icon = node_def.icon
    end
  end
end

local function collect_root_subtree_ids(root_id, result, seen)
  if seen[root_id] then
    return
  end
  seen[root_id] = true
  result[#result + 1] = root_id

  local node_def = NODE_BY_ID[root_id]
  for _, next_id in ipairs(node_def and node_def.next_ids or {}) do
    collect_root_subtree_ids(next_id, result, seen)
  end
end

for _, root_id in ipairs(ROOT_NODE_IDS) do
  local subtree_ids = {}
  collect_root_subtree_ids(root_id, subtree_ids, {})
  ROOT_SUBTREE_NODE_IDS[root_id] = subtree_ids

  local root_def = NODE_BY_ID[root_id]
  local progress_node_ids = {}
  local stage_node_ids = {}
  for _, def in ipairs(LINE_BY_ID[root_def and root_def.line_id] or {}) do
    progress_node_ids[#progress_node_ids + 1] = def.id
  end
  for _, node_id in ipairs(subtree_ids) do
    local node_def = NODE_BY_ID[node_id]
    local tier = tonumber(node_def and node_def.tier) or 1
    stage_node_ids[tier] = stage_node_ids[tier] or {}
    stage_node_ids[tier][#stage_node_ids[tier] + 1] = node_id
  end
  ROOT_SET_PROGRESS_NODE_IDS[root_id] = progress_node_ids
  ROOT_STAGE_NODE_IDS[root_id] = stage_node_ids

  local ordered_tiers = {}
  for tier in pairs(stage_node_ids) do
    ordered_tiers[#ordered_tiers + 1] = tier
  end
  table.sort(ordered_tiers)
  ROOT_STAGE_TIERS[root_id] = ordered_tiers
end

local function add_bonus_value(target, key, value)
  if not target or not key or value == nil or value == 0 then
    return
  end
  target[key] = (target[key] or 0) + value
end

local function remove_bonus_value(target, key, value)
  if not target or not key or value == nil or value == 0 then
    return
  end
  target[key] = (target[key] or 0) - value
  if target[key] == 0 then
    target[key] = nil
  end
end

local function merge_bonus_pack(target, source)
  if not target or not source then
    return
  end
  for key, value in pairs(source) do
    add_bonus_value(target, key, value)
  end
end

local function subtract_bonus_pack(target, source)
  if not target or not source then
    return
  end
  for key, value in pairs(source) do
    remove_bonus_value(target, key, value)
  end
end

local function copy_bonus_pack(source)
  local result = {}
  merge_bonus_pack(result, source)
  return result
end

local function get_refresh_cost(paid_count)
  local index = (paid_count or 0) + 1
  if BondDrawConfig.refresh_costs[index] ~= nil then
    return BondDrawConfig.refresh_costs[index]
  end
  return BondDrawConfig.refresh_costs[#BondDrawConfig.refresh_costs] or 100
end

local function get_runtime(state)
  return state and state.bond_runtime or nil
end

local function get_node_def(node_id)
  return node_id and NODE_BY_ID[node_id] or nil
end

local function append_route_tags(tags, node_def)
  if not tags or not node_def then
    return
  end

  for _, tag in ipairs(node_def.route_tags or {}) do
    tags[tag] = true
  end
end

local function build_static_attr_pack(state, node_def)
  local result = {}
  local root_meta = node_def and node_def.parent_id == nil and ROOT_SET_DOC_META[node_def.id] or nil
  if root_meta then
    merge_bonus_pack(result, root_meta.base_attr)
    if is_root_set_complete(state, node_def.id) then
      merge_bonus_pack(result, root_meta.set_attr)
    end
    return result
  end
  merge_bonus_pack(result, node_def and node_def.attr or {})
  return result
end

local function build_static_runtime_pack(state, node_def)
  local root_meta = node_def and node_def.parent_id == nil and ROOT_SET_DOC_META[node_def.id] or nil
  if root_meta then
    local result = copy_bonus_pack(root_meta.base_runtime or {})
    if is_root_set_complete(state, node_def.id) then
      merge_bonus_pack(result, root_meta.set_runtime or {})
    end
    return result
  end
  return copy_bonus_pack(node_def and node_def.runtime or {})
end

local function ensure_node_state(runtime, node_id)
  runtime.node_runtime_state[node_id] = runtime.node_runtime_state[node_id] or {}
  runtime.node_runtime_handles[node_id] = runtime.node_runtime_handles[node_id] or {}
  return runtime.node_runtime_state[node_id], runtime.node_runtime_handles[node_id]
end

local function apply_static_pack(runtime, node_id, node_def)
  runtime.applied_node_attr_bonuses[node_id] = build_static_attr_pack(runtime.state_ref, node_def)
  runtime.applied_node_runtime_bonuses[node_id] = build_static_runtime_pack(runtime.state_ref, node_def)
end

local function clear_static_pack(runtime, node_id)
  runtime.applied_node_attr_bonuses[node_id] = nil
  runtime.applied_node_runtime_bonuses[node_id] = nil
end

local function build_template_context(state, node_def)
  local runtime = get_runtime(state)
  local node_state, node_handles = ensure_node_state(runtime, node_def.id)
  return {
    state = state,
    runtime = runtime,
    node_def = node_def,
    node_state = node_state,
    node_handles = node_handles,
    add_bonus_value = add_bonus_value,
    remove_bonus_value = remove_bonus_value,
    merge_bonus_pack = merge_bonus_pack,
    subtract_bonus_pack = subtract_bonus_pack,
    apply_static_pack = apply_static_pack,
    clear_static_pack = clear_static_pack,
  }
end

local function activate_node_runtime(state, node_def)
  local runtime = get_runtime(state)
  if not runtime or not node_def or runtime.active_node_ids[node_def.id] then
    return
  end
  BondTemplates.get_template(node_def.template).activate(build_template_context(state, node_def))
  runtime.active_node_ids[node_def.id] = true
end

local function deactivate_node_runtime(state, node_def)
  local runtime = get_runtime(state)
  if not runtime or not node_def or not runtime.active_node_ids[node_def.id] then
    return
  end
  BondTemplates.get_template(node_def.template).deactivate(build_template_context(state, node_def))
  runtime.active_node_ids[node_def.id] = nil
  runtime.node_runtime_handles[node_def.id] = nil
  runtime.node_runtime_state[node_def.id] = nil
  clear_static_pack(runtime, node_def.id)
end

local function ensure_runtime(state)
  if not state then
    return nil
  end
  state.bond_runtime = state.bond_runtime or M.create_runtime()
  state.bond_runtime.pool_node_ids = state.bond_runtime.pool_node_ids or {}
  state.bond_runtime.completed_root_sets = state.bond_runtime.completed_root_sets or {}
  state.bond_runtime.consumed_root_sets = state.bond_runtime.consumed_root_sets or {}
  state.bond_runtime.fused_root_sets = state.bond_runtime.fused_root_sets or {}
  state.bond_runtime.completed_root_set_modes = state.bond_runtime.completed_root_set_modes or {}
  state.bond_runtime.completed_root_set_attr_bonuses = state.bond_runtime.completed_root_set_attr_bonuses or {}
  state.bond_runtime.completed_root_set_runtime_bonuses = state.bond_runtime.completed_root_set_runtime_bonuses or {}
  state.bond_runtime.state_ref = state
  return state.bond_runtime
end

local function get_root_active_stage_tier(state, root_id)
  local runtime = get_runtime(state)
  local stage_tiers = root_id and ROOT_STAGE_TIERS[root_id] or nil
  if not runtime or not stage_tiers or #stage_tiers == 0 then
    return nil
  end
  if runtime.completed_root_sets[root_id] ~= true then
    return stage_tiers[1]
  end
  for index = 2, #stage_tiers do
    local tier = stage_tiers[index]
    for _, node_id in ipairs(ROOT_STAGE_NODE_IDS[root_id][tier] or {}) do
      if runtime.unlocked_node_ids[node_id] ~= true then
        return tier
      end
    end
  end
  return nil
end

local function seed_active_stage_nodes_into_pool(runtime)
  if not runtime then
    return
  end
  runtime.pool_node_ids = runtime.pool_node_ids or {}
  for _, root_id in ipairs(ROOT_NODE_IDS) do
    local node_def = NODE_BY_ID[root_id]
    local group_started = node_def and node_def.group_id and runtime.state_ref and is_group_started(runtime.state_ref, node_def.group_id)
    local allow_root = BondPickConfig.include_group_choices ~= true or group_started
    local active_tier = allow_root and runtime.state_ref and get_root_active_stage_tier(runtime.state_ref, root_id) or nil
    for _, node_id in ipairs(active_tier and ROOT_STAGE_NODE_IDS[root_id][active_tier] or {}) do
      runtime.pool_node_ids[node_id] = true
    end
  end
end

is_group_started = function(state, group_id)
  local runtime = get_runtime(state)
  if not runtime or not group_id then
    return false
  end
  if runtime.unlocked_group_ids and runtime.unlocked_group_ids[group_id] == true then
    return true
  end

  for _, root_id in ipairs(GROUP_ROOT_IDS_BY_GROUP[group_id] or {}) do
    if runtime.completed_root_sets and runtime.completed_root_sets[root_id] == true then
      return true
    end
    for _, node_id in ipairs(ROOT_SUBTREE_NODE_IDS[root_id] or { root_id }) do
      if runtime.unlocked_node_ids and runtime.unlocked_node_ids[node_id] == true then
        return true
      end
    end
  end
  return false
end

local function get_group_choice_defs(state)
  local runtime = ensure_runtime(state)
  if not runtime then
    return {}
  end

  local result = {}
  for _, group_id in ipairs(GROUP_CHOICE_ORDER) do
    local group_def = GROUP_CHOICE_DEFS[group_id]
    if group_def and not is_group_started(state, group_id) then
      result[#result + 1] = group_def
    end
  end
  return result
end

local function unlock_group_choice(state, group_id)
  local runtime = ensure_runtime(state)
  local group_def = GROUP_CHOICE_DEFS[group_id]
  if not runtime or not group_def or runtime.unlocked_group_ids[group_id] == true then
    return false
  end

  runtime.unlocked_group_ids[group_id] = true
  runtime.last_unlocked_node_id = nil
  runtime.owned_node_order[#runtime.owned_node_order + 1] = group_def.id
  seed_active_stage_nodes_into_pool(runtime)
  M.rebuild_candidate_nodes(state)
  return true
end

local function apply_unlock_rewards(state, node_def)
  local reward_pack = node_def and node_def.unlock_rewards or nil
  if not state or not reward_pack then
    return nil
  end

  local granted = {}
  state.resources = state.resources or {}

  if (reward_pack.gold or 0) ~= 0 then
    state.resources.gold = (state.resources.gold or 0) + reward_pack.gold
    granted[#granted + 1] = string.format('金币 %+d', reward_pack.gold)
  end
  if (reward_pack.wood or 0) ~= 0 then
    state.resources.wood = (state.resources.wood or 0) + reward_pack.wood
    granted[#granted + 1] = string.format('木材 %+d', reward_pack.wood)
  end
  if (reward_pack.exp or 0) ~= 0 then
    state.resources.exp = (state.resources.exp or 0) + reward_pack.exp
    granted[#granted + 1] = string.format('经验 %+d', reward_pack.exp)
  end

  if #granted == 0 then
    return nil
  end
  return granted
end

local function set_line_progress(runtime, node_def)
  if not runtime or not node_def or not node_def.line_id then
    return
  end
  local current = runtime.line_progress[node_def.line_id] or 0
  if (node_def.tier or 0) > current then
    runtime.line_progress[node_def.line_id] = node_def.tier
  end
end

local function format_line_label(node_def)
  if not node_def then
    return '未知链路'
  end

  local line_defs = LINE_BY_ID[node_def.line_id] or {}
  local line_root = line_defs[1]
  local group_label = GROUP_LABELS[node_def.group_id] or node_def.group_id or '未知分类'
  local line_label = line_root and line_root.display_name and line_root.display_name ~= ''
      and string.format('%s线', line_root.display_name)
      or (node_def.line_id or '未知路线')

  return string.format('%s · %s · 第%d层', group_label, line_label, node_def.tier or 0)
end

local function trim_inline_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  return (text:gsub('[。；;，,%s]+$', ''))
end

local function is_transition_advanced_text(text)
  if type(text) ~= 'string' then
    return false
  end

  local value = trim_inline_text(text)
  if value == '' then
    return false
  end

  if string.find(value, '已凑齐，开启后续分支', 1, true)
      or string.find(value, '已凑齐,开启后续分支', 1, true)
      or string.find(value, '已凑齐，解锁后续分支', 1, true)
      or string.find(value, '已凑齐,解锁后续分支', 1, true) then
    return true
  end

  if string.find(value, '我要玩', 1, true)
      and string.find(value, '卡池中加入', 1, true) then
    return true
  end

  return false
end

local function format_value_text_lines(text)
  if type(text) ~= 'string' or text == '' then
    return ''
  end

  local normalized = text
  normalized = normalized:gsub('。%s*', '。\n')
  normalized = normalized:gsub('([。])([^\n：。]+：)', '%1\n%2')
  normalized = normalized:gsub('，', '\n')
  normalized = normalized:gsub(',%s*', '\n')
  normalized = normalized:gsub('；', '\n')
  normalized = normalized:gsub(';%s*', '\n')
  normalized = normalized:gsub('\n+', '\n')
  normalized = normalized:gsub('^%s+', '')
  normalized = normalized:gsub('%s+$', '')
  return normalized
end

local MANUAL_COLOR_KEYWORDS = BondMiscConfig.manual_color_keywords or {}

local function find_manual_color_match(text, start_pos)
  local best_start, best_end, best_color

  for _, keyword in ipairs(MANUAL_COLOR_KEYWORDS.green) do
    local s, e = string.find(text, keyword, start_pos, true)
    if s and (not best_start or s < best_start or (s == best_start and e > best_end)) then
      best_start, best_end, best_color = s, e, 'green'
    end
  end

  for _, pattern in ipairs(MANUAL_COLOR_KEYWORDS.cyan) do
    local s, e = string.find(text, pattern, start_pos)
    if s and (not best_start or s < best_start or (s == best_start and e > best_end)) then
      best_start, best_end, best_color = s, e, 'cyan'
    end
  end

  return best_start, best_end, best_color
end

local function append_manual_color_segments(segments, text, default_color)
  if type(text) ~= 'string' or text == '' then
    return
  end

  local cursor = 1
  local length = #text

  while cursor <= length do
    local match_start, match_end, match_color = find_manual_color_match(text, cursor)
    if not match_start then
      segments[#segments + 1] = {
        text = string.sub(text, cursor),
        color = default_color,
      }
      break
    end

    if match_start > cursor then
      segments[#segments + 1] = {
        text = string.sub(text, cursor, match_start - 1),
        color = default_color,
      }
    end

    segments[#segments + 1] = {
      text = string.sub(text, match_start, match_end),
      color = match_color,
    }
    cursor = match_end + 1
  end
end

local function build_manual_color_segments(text, default_color)
  if type(text) ~= 'string' or text == '' then
    return nil
  end

  local segments = {}
  local line_index = 0
  for line in string.gmatch(text .. '\n', '(.-)\n') do
    if line_index > 0 then
      segments[#segments + 1] = {
        text = '\n',
        color = default_color,
      }
    end
    line_index = line_index + 1

    local card_name = string.match(line, '^([^：\n]+：)')
    if card_name and card_name ~= '' then
      segments[#segments + 1] = {
        text = card_name,
        color = 'gold',
      }
      append_manual_color_segments(segments, string.sub(line, #card_name + 1), default_color)
    else
      append_manual_color_segments(segments, line, default_color)
    end
  end

  return segments
end

local function build_fallback_effect_parts(node_def)
  local parts = {}
  for key, value in pairs(node_def and node_def.attr or {}) do
    parts[#parts + 1] = string.format('%s %+g', key, value)
  end
  for key, value in pairs(node_def and node_def.runtime or {}) do
    if PER_SECOND_ATTR_KEYS[key] == nil then
      parts[#parts + 1] = string.format('%s %+g', key, value)
    end
  end
  return parts
end

local function get_choice_single_text(node_def)
  if not node_def then
    return ''
  end
  if type(node_def.desc) == 'table' and node_def.desc.single and node_def.desc.single ~= '' then
    return node_def.desc.single
  end
  local root_meta = node_def.parent_id == nil and ROOT_SET_DOC_META[node_def.id] or nil
  if root_meta and root_meta.base_text and root_meta.base_text ~= '' then
    return root_meta.base_text
  end
  if type(node_def.desc) == 'string' then
    return node_def.desc
  end
  return table.concat(build_fallback_effect_parts(node_def), '；')
end

local function get_choice_advanced_text(node_def)
  if type(node_def and node_def.desc) == 'table' and node_def.desc.advanced and node_def.desc.advanced ~= '' then
    if is_transition_advanced_text(node_def.desc.advanced) then
      return ''
    end
    return node_def.desc.advanced
  end
  return ''
end

local function build_choice_next_text(node_def)
  return ''
--[[
  if not node_def or not node_def.next_ids or #node_def.next_ids == 0 then
    return ''
  end

  local parts = {}
  for _, next_id in ipairs(node_def.next_ids) do
    local next_def = NODE_BY_ID[next_id]
    if next_def then
      local next_single = trim_inline_text(get_choice_single_text(next_def))
      if next_single ~= '' then
        parts[#parts + 1] = string.format('%s（%s）', next_def.display_name, next_single)
      else
        parts[#parts + 1] = next_def.display_name
      end
    end
  end

  if #parts == 0 then
    return ''
  end
  return '后继：' .. table.concat(parts, '；')
]]
end

local function build_choice_current_text(node_def)
  local single = trim_inline_text(get_choice_single_text(node_def))
  if single == '' then
    return ''
  end
  return string.format('当前：%s。', single)
end

local function build_node_summary_text(node_def)
  local single = trim_inline_text(get_choice_single_text(node_def))
  if single == '' then
    return ''
  end
  return single
end

local function format_root_title(root_def)
  local group_label = GROUP_LABELS[root_def and root_def.group_id] or root_def and root_def.group_id or '未知分类'
  local line_label = root_def and root_def.display_name and root_def.display_name ~= ''
      and string.format('%s线', root_def.display_name)
      or '未知路线'
  return string.format('%s · %s', group_label, line_label)
end

local function get_line_root_def(node_def)
  local line_defs = node_def and LINE_BY_ID[node_def.line_id] or nil
  return line_defs and line_defs[1] or node_def
end

local function get_set_root_def(node_def)
  local current = node_def
  local guard = 0
  while current and current.parent_id and guard < 16 do
    current = NODE_BY_ID[current.parent_id]
    guard = guard + 1
  end
  return current or node_def
end

local function get_node_tier(node_def)
  return tonumber(node_def and node_def.tier) or 1
end

local function get_root_set_doc_meta(node_def)
  local root_def = get_set_root_def(node_def)
  return root_def and ROOT_SET_DOC_META[root_def.id] or nil
end

local function get_root_set_completion_mode(root_id)
  local meta = root_id and ROOT_SET_DOC_META[root_id] or nil
  if not meta then
    return nil
  end
  return meta.completion_mode or 'consume_all'
end

local function count_unlocked_root_set_nodes(state, root_id)
  local unlocked_count = 0
  for _, node_id in ipairs(ROOT_SET_PROGRESS_NODE_IDS[root_id] or {}) do
    if M.is_node_unlocked(state, node_id) then
      unlocked_count = unlocked_count + 1
    end
  end
  return unlocked_count
end

is_root_set_complete = function(state, root_id)
  local runtime = get_runtime(state)
  if runtime and runtime.completed_root_sets and runtime.completed_root_sets[root_id] == true then
    return true
  end
  local meta = root_id and ROOT_SET_DOC_META[root_id] or nil
  if not meta then
    return false
  end
  return count_unlocked_root_set_nodes(state, root_id) >= (meta.required_count or 0)
end

local function apply_completed_root_set_bonus_pack(target, runtime, field_name)
  if not target or not runtime or not field_name then
    return
  end
  for _, bonus_pack in pairs(runtime[field_name] or {}) do
    merge_bonus_pack(target, bonus_pack)
  end
end

local function remove_owned_node(runtime, node_id)
  if not runtime or not node_id then
    return
  end
  local next_owned = {}
  for _, owned_id in ipairs(runtime.owned_node_order or {}) do
    if owned_id ~= node_id then
      next_owned[#next_owned + 1] = owned_id
    end
  end
  runtime.owned_node_order = next_owned
end

local function persist_completed_root_set_bonuses(state, root_id)
  local runtime = get_runtime(state)
  if not runtime or not root_id then
    return
  end
  local attr_pack = {}
  local runtime_pack = {}
  for _, node_id in ipairs(ROOT_SET_PROGRESS_NODE_IDS[root_id] or { root_id }) do
    if runtime.unlocked_node_ids[node_id] == true then
      local node_def = NODE_BY_ID[node_id]
      if node_def then
        merge_bonus_pack(attr_pack, build_static_attr_pack(state, node_def))
        merge_bonus_pack(runtime_pack, build_static_runtime_pack(state, node_def))
      end
    end
  end
  runtime.completed_root_set_attr_bonuses[root_id] = attr_pack
  runtime.completed_root_set_runtime_bonuses[root_id] = runtime_pack
end

local function remove_root_set_nodes_from_runtime(state, root_id)
  local runtime = get_runtime(state)
  if not runtime or not root_id then
    return
  end

  for _, node_id in ipairs(ROOT_SET_PROGRESS_NODE_IDS[root_id] or {}) do
    local node_def = NODE_BY_ID[node_id]
    if node_def and runtime.active_node_ids[node_id] then
      deactivate_node_runtime(state, node_def)
    end
    runtime.unlocked_node_ids[node_id] = nil
    runtime.pool_node_ids[node_id] = nil
    runtime.candidate_node_ids[node_id] = nil
    remove_owned_node(runtime, node_id)
  end
end

local function resolve_root_set_completion(state, root_id)
  local runtime = get_runtime(state)
  local mode = get_root_set_completion_mode(root_id)
  if not runtime or not root_id or not mode then
    return false
  end
  if runtime.completed_root_sets[root_id] == true then
    return false
  end
  if not is_root_set_complete(state, root_id) then
    return false
  end

  runtime.completed_root_sets[root_id] = true
  runtime.completed_root_set_modes[root_id] = mode
  persist_completed_root_set_bonuses(state, root_id)

  if mode == 'consume_all' then
    runtime.consumed_root_sets[root_id] = true
    remove_root_set_nodes_from_runtime(state, root_id)
    M.refresh_all_nodes(state)
    return true
  end

  if mode == 'fuse_to_node' then
    runtime.fused_root_sets[root_id] = true
    return true
  end

  return false
end

local function count_unlocked_nodes(state, node_ids)
  local unlocked_count = 0
  for _, node_id in ipairs(node_ids or {}) do
    if M.is_node_unlocked(state, node_id) then
      unlocked_count = unlocked_count + 1
    end
  end
  return unlocked_count
end

local function is_root_line_node(node_def)
  if not node_def then
    return false
  end
  local root_def = get_set_root_def(node_def)
  return root_def and node_def.line_id == root_def.line_id or false
end

local function get_branch_anchor_def(node_def)
  if not node_def or is_root_line_node(node_def) then
    return nil
  end

  local current = node_def
  local anchor = node_def
  local root_def = get_set_root_def(node_def)
  local guard = 0
  while current and current.parent_id and guard < 16 do
    local parent_def = NODE_BY_ID[current.parent_id]
    if not parent_def or (root_def and parent_def.line_id == root_def.line_id) then
      anchor = current
      break
    end
    anchor = parent_def
    current = parent_def
    guard = guard + 1
  end
  return anchor
end

local function build_branch_progress_node_ids(node_def)
  local anchor_def = get_branch_anchor_def(node_def)
  if not anchor_def then
    return {}
  end

  local result = {}
  local seen = {}
  result[#result + 1] = anchor_def.id
  seen[anchor_def.id] = true

  local line_defs = LINE_BY_ID[node_def.line_id] or {}
  for _, def in ipairs(line_defs) do
    if not seen[def.id] then
      result[#result + 1] = def.id
      seen[def.id] = true
    end
  end
  return result
end

local function build_effect_segment_node_ids(node_def)
  if not node_def then
    return {}
  end

  local target_advanced = trim_inline_text(get_choice_advanced_text(node_def))
  if target_advanced == '' then
    return {}
  end

  local result = {}
  for _, def in ipairs(LINE_BY_ID[node_def.line_id] or {}) do
    if trim_inline_text(get_choice_advanced_text(def)) == target_advanced then
      result[#result + 1] = def.id
    end
  end
  return result
end

local function get_display_set_root_def(node_def)
  if not node_def then
    return nil
  end

  if is_root_line_node(node_def) then
    return get_set_root_def(node_def) or node_def
  end

  local segment_node_ids = build_effect_segment_node_ids(node_def)
  if #segment_node_ids > 0 then
    return NODE_BY_ID[segment_node_ids[1]] or node_def
  end

  local anchor_def = get_branch_anchor_def(node_def)
  if anchor_def then
    return anchor_def
  end

  return get_set_root_def(node_def) or node_def
end

local function build_choice_progress_values(state, node_def)
  if not node_def then
    return 0, 0
  end

  local root_def = get_set_root_def(node_def)
  local root_meta = root_def and ROOT_SET_DOC_META[root_def.id] or nil
  if root_def and root_meta and is_root_line_node(node_def) then
    local unlocked_count = math.min(
      root_meta.required_count or 0,
      count_unlocked_root_set_nodes(state, root_def.id)
    )
    return unlocked_count, root_meta.required_count or 0
  end

  if node_def.parent_id then
    local segment_node_ids = build_effect_segment_node_ids(node_def)
    if #segment_node_ids > 0 then
      local unlocked_count = count_unlocked_nodes(state, segment_node_ids)
      return unlocked_count, #segment_node_ids
    end

    local branch_node_ids = build_branch_progress_node_ids(node_def)
    if #branch_node_ids > 0 then
      local unlocked_count = count_unlocked_nodes(state, branch_node_ids)
      return unlocked_count, #branch_node_ids
    end
  end

  if not node_def.parent_id then
    local required_count = math.max(2, #(node_def.next_ids or {}))
    local unlocked_count = count_unlocked_nodes(state, node_def.next_ids or {})
    return unlocked_count, required_count
  end

  local line_root_def = get_line_root_def(node_def)
  local line_defs = line_root_def and LINE_BY_ID[line_root_def.line_id] or {}
  local line_node_ids = {}
  for _, def in ipairs(line_defs or {}) do
    if def.id ~= (line_root_def and line_root_def.parent_id or nil) then
      line_node_ids[#line_node_ids + 1] = def.id
    end
  end

  local unlocked_count = count_unlocked_nodes(state, line_node_ids)
  local required_count = math.max(2, #line_node_ids)
  return unlocked_count, required_count
end

local function build_line_progress_values(state, node_def)
  local set_root_def = get_display_set_root_def(node_def)
  local unlocked_count, required_count = build_choice_progress_values(state, node_def)
  return string.format(
    '%s(%d/%d)',
    set_root_def and set_root_def.display_name or (node_def and node_def.display_name) or '未知羁绊',
    unlocked_count,
    required_count
  )
end

local function build_line_progress_text(state, node_def)
  local unlocked_count, required_count = build_choice_progress_values(state, node_def)
  return string.format('%d/%d', unlocked_count, required_count)
end

local function trim_choice_prefix(text)
  local trimmed = trim_inline_text(text)
  trimmed = trimmed:gsub('^当前：', '')
  trimmed = trimmed:gsub('^后继：', '')
  trimmed = trimmed:gsub('^进阶链路：', '')
  trimmed = trimmed:gsub('^终局方向：', '')
  trimmed = trimmed:gsub('^终阶节点：', '')
  return trim_inline_text(trimmed)
end

local function trim_choice_name_punctuation(text)
  local value = type(text) == 'string' and text or ''
  local changed = true
  while changed and value ~= '' do
    changed = false
    if string.sub(value, -3) == '。' or string.sub(value, -3) == '；' or string.sub(value, -3) == '，' then
      value = string.sub(value, 1, -4)
      changed = true
    elseif string.sub(value, -1) == ';'
        or string.sub(value, -1) == ','
        or string.sub(value, -1) == ' '
        or string.sub(value, -1) == '\t'
        or string.sub(value, -1) == '\n'
        or string.sub(value, -1) == '\r' then
      value = string.sub(value, 1, -2)
      changed = true
    end
  end
  return value
end

local function get_choice_card_name_text(node_def)
  if not node_def then
    return ''
  end

  local single_text = get_choice_single_text(node_def)
  for _, prefix in ipairs({ '当前：', '后继：', '进阶链路：', '终局方向：', '终阶节点：' }) do
    if string.sub(single_text, 1, #prefix) == prefix then
      single_text = string.sub(single_text, #prefix + 1)
      break
    end
  end
  single_text = trim_choice_name_punctuation(single_text)
  if single_text ~= '' then
    local colon_pos = string.find(single_text, '：', 1, true)
    if not colon_pos then
      colon_pos = string.find(single_text, ':', 1, true)
    end
    local headline = colon_pos and string.sub(single_text, 1, colon_pos - 1) or ''
    headline = trim_choice_name_punctuation(headline)
    if headline ~= '' then
      return headline
    end

    local compact_single = trim_choice_name_punctuation(single_text)
    if compact_single ~= ''
        and not string.find(compact_single, '，', 1, true)
        and not string.find(compact_single, ',', 1, true)
        and not string.find(compact_single, '\n', 1, true) then
      return compact_single
    end
  end

  return node_def.display_name or ''
end

local function build_choice_effect_title(state, node_def)
  if node_def and node_def.parent_id then
    return ''
  end
  local root_def = get_set_root_def(node_def)
  local line_name = root_def and root_def.display_name or node_def and node_def.display_name or '未知羁绊'
  return string.format('激活[%s]套装效果：', line_name)
end

local function build_choice_effect_text(node_def)
  if node_def and node_def.parent_id then
    return ''
  end
  local root_def = get_set_root_def(node_def)
  local root_meta = root_def and ROOT_SET_DOC_META[root_def.id] or nil
  if root_meta and root_meta.effect_text and root_meta.effect_text ~= '' then
    return trim_choice_prefix(root_meta.effect_text)
  end
  return trim_choice_prefix(get_choice_single_text(root_def))
end

local function compact_tip_text(text)
  local compact = trim_choice_prefix(text)
  compact = compact:gsub('\r', '')
  compact = compact:gsub('\n', '')
  compact = compact:gsub('%s+', '')
  return trim_inline_text(compact)
end

local function split_tip_lines(text, max_lines)
  local lines = {}
  local normalized = trim_choice_prefix(text)
  if normalized == '' then
    return lines
  end
  normalized = normalized:gsub('\r', '')
  for line in normalized:gmatch('[^\n]+') do
    local trimmed = trim_inline_text(line)
    if trimmed ~= '' then
      lines[#lines + 1] = trimmed
    end
    if max_lines and #lines >= max_lines then
      break
    end
  end
  return lines
end

local function build_owned_group_tip_payload(group_def)
  if not group_def then
    return nil
  end
  local effect_text = string.format('选择后开放[%s]主链根节点。', group_def.display_name or '该分组')
  local tip_model = BondTipModelBuilder.build({
    quality_text = M.get_quality_label(group_def.quality),
    set_name_text = group_def.display_name or '',
    progress_text = '(未开启)',
    icon_res = group_def.icon,
    item_name_text = group_def.display_name or '未命名分组',
    bonus_text = group_def.desc or '',
    effect_index_text = '[效果1]',
    effect_body_text = effect_text,
  })
  return {
    kind = 'bond',
    quality = group_def.quality or 'rare',
    badge_text = M.get_quality_label(group_def.quality),
    icon_res = group_def.icon,
    title_text = group_def.display_name or '未命名分组',
    bonus_lines = tip_model.bonus_lines,
    effect_area_bonus_count = math.min(3, #tip_model.bonus_lines),
    tip_model = tip_model,
  }
end

local function build_owned_node_tip_payload(state, node_def)
  if not node_def then
    return nil
  end

  local set_root_def = get_set_root_def(node_def) or node_def
  local card_name_text = get_choice_card_name_text(node_def)
  local current_text = build_choice_current_text(node_def)
  local advanced_text = get_choice_advanced_text(node_def)
  local next_text = build_choice_next_text(node_def)
  local effect_title = build_choice_effect_title(state, node_def)
  local effect_text = build_choice_effect_text(node_def)
  local progress_text = build_line_progress_text(state, node_def)
  local tip_model = BondTipModelBuilder.build({
    quality_text = M.get_quality_label(node_def.quality),
    set_name_text = set_root_def and set_root_def.display_name or '',
    progress_text = progress_text ~= '' and string.format('(%s)', progress_text) or '',
    icon_res = node_def.icon,
    item_name_text = card_name_text ~= '' and card_name_text or '未命名羁绊',
    current_text = current_text,
    effect_body_text = advanced_text,
    set_title_text = effect_title,
    effect_text = effect_text,
  })

  return {
    kind = 'bond',
    quality = node_def.quality or 'rare',
    badge_text = M.get_quality_label(node_def.quality),
    icon_res = node_def.icon,
    title_text = card_name_text ~= '' and card_name_text or '未命名羁绊',
    bonus_lines = tip_model.bonus_lines,
    effect_area_bonus_count = math.min(3, #tip_model.bonus_lines),
    tip_model = tip_model,
  }
end

local function build_choice_body_blocks(state, node_def, current_text, advanced_text, effect_title, effect_text)
  local body_blocks = {}
  local value_text = format_value_text_lines(trim_choice_prefix(current_text))
  if value_text ~= '' then
    body_blocks[#body_blocks + 1] = {
      kind = 'value',
      text = value_text,
      color = 'green',
      segments = build_manual_color_segments(value_text, 'white'),
    }
  end
  local own_effect_text = format_value_text_lines(trim_choice_prefix(advanced_text))
  if node_def and node_def.parent_id and own_effect_text ~= '' then
    body_blocks[#body_blocks + 1] = {
      kind = 'effect_title',
      text = '套装效果：',
      color = 'gold',
      segments = {
        {
          text = '套装效果：',
          color = 'gold',
        },
      },
    }
    body_blocks[#body_blocks + 1] = {
      kind = 'effect',
      text = own_effect_text,
      color = 'dim',
      segments = build_manual_color_segments(own_effect_text, 'dim'),
    }
  end
  if effect_title ~= '' then
    body_blocks[#body_blocks + 1] = {
      kind = 'effect_title',
      text = effect_title,
      color = 'gold',
      segments = {
        {
          text = effect_title,
          color = 'gold',
        },
      },
    }
  end
  if effect_text ~= '' then
    body_blocks[#body_blocks + 1] = {
      kind = 'effect',
      text = effect_text,
      color = 'dim',
      segments = build_manual_color_segments(effect_text, 'dim'),
    }
  end
  return body_blocks
end

local function build_def_name_list(defs, max_count)
  local names = {}
  local limit = math.max(1, max_count or #defs)
  for index, def in ipairs(defs or {}) do
    if index > limit then
      break
    end
    names[#names + 1] = def.display_name
  end
  if #defs > limit then
    names[#names + 1] = string.format('等%d个', #defs)
  end
  return table.concat(names, '、')
end

local function build_root_progress_entry(state, root_id)
  local root_def = NODE_BY_ID[root_id]
  local runtime = get_runtime(state)
  if not root_def then
    return nil
  end

  if runtime and runtime.completed_root_sets and runtime.completed_root_sets[root_id] == true then
    return {
      started = true,
      text = string.format(
        '%s %d/%d | %s',
        format_root_title(root_def),
        ROOT_SET_DOC_META[root_id] and ROOT_SET_DOC_META[root_id].required_count or 0,
        ROOT_SET_DOC_META[root_id] and ROOT_SET_DOC_META[root_id].required_count or 0,
        runtime.consumed_root_sets and runtime.consumed_root_sets[root_id] == true and '已吞噬完成' or '已完成'
      ),
    }
  end

  local subtree_ids = ROOT_SUBTREE_NODE_IDS[root_id] or { root_id }
  local unlocked_defs = {}
  local frontier_defs = {}

  for _, node_id in ipairs(subtree_ids) do
    local node_def = NODE_BY_ID[node_id]
    if node_def then
      if M.is_node_unlocked(state, node_def.id) then
        unlocked_defs[#unlocked_defs + 1] = node_def
      elseif M.can_unlock_node(state, node_def.id) then
        frontier_defs[#frontier_defs + 1] = node_def
      end
    end
  end

  local unlocked_count = #unlocked_defs
  local total_count = #subtree_ids
  local title = string.format('%s %d/%d', format_root_title(root_def), unlocked_count, total_count)

  if #frontier_defs > 0 then
    return {
      started = unlocked_count > 0,
      text = string.format('%s | 可选：%s', title, build_def_name_list(frontier_defs, 3)),
    }
  end

  if unlocked_count > 0 then
    return {
      started = true,
      text = string.format('%s | 已完成', title),
    }
  end

  local summary = build_node_summary_text(root_def)
  if summary ~= '' then
    return {
      started = false,
      text = string.format('%s | 起始：%s', title, summary),
    }
  end

  return {
    started = false,
    text = title,
  }
end

local function build_root_overview_entry(state, root_id)
  local root_def = NODE_BY_ID[root_id]
  local runtime = get_runtime(state)
  if not root_def then
    return nil
  end

  local subtree_ids = ROOT_SUBTREE_NODE_IDS[root_id] or { root_id }
  local unlocked_defs = {}
  local frontier_defs = {}

  for _, node_id in ipairs(subtree_ids) do
    local node_def = NODE_BY_ID[node_id]
    if node_def then
      if M.is_node_unlocked(state, node_def.id) then
        unlocked_defs[#unlocked_defs + 1] = node_def
      elseif M.can_unlock_node(state, node_def.id) then
        frontier_defs[#frontier_defs + 1] = node_def
      end
    end
  end

  local required_count = ROOT_SET_DOC_META[root_id] and ROOT_SET_DOC_META[root_id].required_count or 0
  local completed = runtime and runtime.completed_root_sets and runtime.completed_root_sets[root_id] == true or false
  local consumed = runtime and runtime.consumed_root_sets and runtime.consumed_root_sets[root_id] == true or false
  local started = #unlocked_defs > 0 or is_group_started(state, root_def.group_id)
  local status = 'locked'

  if consumed then
    status = 'consumed'
  elseif completed then
    status = 'completed'
  elseif #unlocked_defs > 0 then
    status = 'in_progress'
  elseif is_group_started(state, root_def.group_id) then
    status = 'available'
  end

  return {
    root_id = root_id,
    group_id = root_def.group_id,
    group_name = GROUP_LABELS[root_def.group_id] or root_def.group_id,
    display_name = root_def.display_name,
    title = format_root_title(root_def),
    status = status,
    started = started,
    completed = completed,
    consumed = consumed,
    unlocked_count = #unlocked_defs,
    total_count = #subtree_ids,
    required_count = required_count,
    progress_text = string.format('%d/%d', #unlocked_defs, #subtree_ids),
    available_next_names = build_def_name_list(frontier_defs, 3),
    available_next_count = #frontier_defs,
    summary = build_node_summary_text(root_def),
    effect_text = trim_choice_prefix((ROOT_SET_DOC_META[root_id] and ROOT_SET_DOC_META[root_id].effect_text) or ''),
  }
end

local function build_choice_desc(node_def)
  local parts = {}
  local current_text = build_choice_current_text(node_def)
  local advanced_text = get_choice_advanced_text(node_def)
  local next_text = build_choice_next_text(node_def)

  if current_text ~= '' then
    parts[#parts + 1] = current_text
  end
  if advanced_text ~= '' then
    parts[#parts + 1] = advanced_text
  end
  if next_text ~= '' then
    parts[#parts + 1] = next_text
  end
  return table.concat(parts, '\n')
end

local function append_preview_segment(parts, text)
  local trimmed = trim_inline_text(text)
  if trimmed == '' then
    return
  end
  parts[#parts + 1] = trimmed
end

local function build_choice_preview_segments(choice)
  local parts = {}

  append_preview_segment(parts, choice and choice.current_text or '')
  append_preview_segment(parts, choice and choice.advanced_text or '')
  append_preview_segment(parts, choice and choice.next_text or '')

  if #parts == 0 then
    append_preview_segment(parts, choice and choice.desc_text or '')
  end

  return parts
end

local function build_choice_entry(state, node_def, index)
  local set_root_def = get_set_root_def(node_def) or node_def
  local display_set_root_def = get_display_set_root_def(node_def) or set_root_def
  local card_name_text = get_choice_card_name_text(node_def)
  local current_text = build_choice_current_text(node_def)
  local advanced_text = get_choice_advanced_text(node_def)
  local next_text = build_choice_next_text(node_def)
  local effect_title = build_choice_effect_title(state, node_def)
  local effect_text = build_choice_effect_text(node_def)
  local subtitle_text = card_name_text ~= '' and card_name_text or node_def.display_name
  local progress_text = build_line_progress_text(state, node_def)

  return {
    index = index,
    node_id = node_def.id,
    display_name = node_def.display_name,
    quality = node_def.quality or 'rare',
    ui_icon = node_def.icon,
    icon = node_def.icon,
    group_id = node_def.group_id,
    line_id = node_def.line_id,
    tier = node_def.tier,
    parent_id = node_def.parent_id,
    next_ids = node_def.next_ids,
    editor_skill_id = node_def.editor_skill_id,
    template = node_def.template,
    title_text = string.format(
      '%s (%s)',
      display_set_root_def and display_set_root_def.display_name or node_def.display_name,
      progress_text
    ),
    subtitle_text = subtitle_text,
    progress_text = '',
    current_text = current_text,
    advanced_text = advanced_text,
    next_text = next_text,
    desc_text = build_choice_desc(node_def),
    value_text = trim_choice_prefix(current_text),
    effect_title = effect_title,
    effect_text = effect_text,
    body_blocks = build_choice_body_blocks(state, node_def, current_text, advanced_text, effect_title, effect_text),
    effect_color_mode = 'auto',
    effect_root_id = set_root_def and set_root_def.id or node_def.id,
    line_root_id = line_root_def and line_root_def.id or node_def.id,
  }
end

local function build_group_choice_entry(group_def, index)
  local title_text = string.format('%s (未开启)', group_def.display_name or '未命名分组')
  local current_text = group_def.desc or ''
  local effect_text = string.format('选择后开放[%s]主链根节点。', group_def.display_name or '该分组')

  return {
    index = index,
    node_id = nil,
    group_choice_id = group_def.id,
    group_id = group_def.group_id,
    display_name = group_def.display_name,
    quality = group_def.quality or 'rare',
    ui_icon = group_def.icon,
    icon = group_def.icon,
    title_text = title_text,
    subtitle_text = '主链分组',
    progress_text = '未开启',
    current_text = current_text,
    advanced_text = '',
    next_text = '',
    desc_text = table.concat({
      current_text,
      effect_text,
    }, '\n'),
    value_text = current_text,
    effect_title = '',
    effect_text = effect_text,
    body_blocks = build_choice_body_blocks(nil, nil, current_text, '', '', effect_text),
    effect_color_mode = 'auto',
  }
end

local function collect_merged_bonus_packs(pack_map)
  local result = {}
  for _, bonus_pack in pairs(pack_map or {}) do
    merge_bonus_pack(result, bonus_pack)
  end
  return result
end

local function append_unique_candidate(target, seen, candidate)
  if not target or not seen or not candidate or not candidate.id or seen[candidate.id] then
    return
  end
  seen[candidate.id] = true
  target[#target + 1] = candidate
end

local function apply_dynamic_bonuses(env, desired_attr, desired_runtime)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime then
    return
  end

  local previous_attr = runtime.dynamic_node_attr_bonuses[SYSTEM_DYNAMIC_NODE_ID] or {}

  do
    local hero = state and state.hero
    local hero_attr_system = env and env.hero_attr_system
    if hero and hero.is_exist and hero:is_exist() then
      local seen = {}
      for attr_name, desired_value in pairs(desired_attr) do
        seen[attr_name] = true
        local delta = desired_value - (previous_attr[attr_name] or 0)
        if delta ~= 0 then
          if hero_attr_system and hero_attr_system.add_attr then
            hero_attr_system.add_attr(hero, attr_name, delta)
          else
            hero:add_attr(attr_name, delta)
          end
        end
      end

      for attr_name, previous_value in pairs(previous_attr) do
        if not seen[attr_name] and previous_value ~= 0 then
          if hero_attr_system and hero_attr_system.add_attr then
            hero_attr_system.add_attr(hero, attr_name, -previous_value)
          else
            hero:add_attr(attr_name, -previous_value)
          end
        end
      end
    end

    if next(desired_attr) then
      runtime.dynamic_node_attr_bonuses[SYSTEM_DYNAMIC_NODE_ID] = copy_bonus_pack(desired_attr)
    else
      runtime.dynamic_node_attr_bonuses[SYSTEM_DYNAMIC_NODE_ID] = nil
    end

    if next(desired_runtime) then
      runtime.dynamic_node_runtime_bonuses[SYSTEM_DYNAMIC_NODE_ID] = copy_bonus_pack(desired_runtime)
    else
      runtime.dynamic_node_runtime_bonuses[SYSTEM_DYNAMIC_NODE_ID] = nil
    end

    if env and env.sync_basic_attack_ability then
      env.sync_basic_attack_ability()
    end
    return
  end

  if state.hero and state.hero:is_exist() then
    local seen = {}
    for attr_name, desired_value in pairs(desired_attr) do
      seen[attr_name] = true
      local delta = desired_value - (previous_attr[attr_name] or 0)
      if delta ~= 0 then
        state.hero:add_attr(attr_name, delta)
      end
    end

    for attr_name, previous_value in pairs(previous_attr) do
      if not seen[attr_name] and previous_value ~= 0 then
        state.hero:add_attr(attr_name, -previous_value)
      end
    end
  end

  if next(desired_attr) then
    runtime.dynamic_node_attr_bonuses[SYSTEM_DYNAMIC_NODE_ID] = copy_bonus_pack(desired_attr)
  else
    runtime.dynamic_node_attr_bonuses[SYSTEM_DYNAMIC_NODE_ID] = nil
  end

  if next(desired_runtime) then
    runtime.dynamic_node_runtime_bonuses[SYSTEM_DYNAMIC_NODE_ID] = copy_bonus_pack(desired_runtime)
  else
    runtime.dynamic_node_runtime_bonuses[SYSTEM_DYNAMIC_NODE_ID] = nil
  end

  if env and env.sync_basic_attack_ability then
    env.sync_basic_attack_ability()
  end
end

local function add_attr_to_hero(env, attr_name, delta)
  if delta == nil or delta == 0 then
    return
  end
  local state = env and env.STATE
  local hero = state and state.hero
  if not hero or not hero.is_exist or not hero:is_exist() then
    return
  end

  local hero_attr_system = env and env.hero_attr_system
  if hero_attr_system and hero_attr_system.add_attr then
    hero_attr_system.add_attr(hero, attr_name, delta)
    return
  end

  if hero.add_attr then
    hero:add_attr(attr_name, delta)
  end
end

local function sync_attr_bonuses_to_hero(env)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  local hero = state and state.hero
  if not runtime or not hero or not hero.is_exist or not hero:is_exist() then
    return
  end

  runtime.synced_hero_attr_bonuses = runtime.synced_hero_attr_bonuses or {}
  local previous = runtime.synced_hero_attr_bonuses
  local desired = M.get_total_attr_bonuses(state)
  local seen = {}

  for attr_name, desired_value in pairs(desired) do
    seen[attr_name] = true
    local delta = (desired_value or 0) - (previous[attr_name] or 0)
    add_attr_to_hero(env, attr_name, delta)
  end

  for attr_name, previous_value in pairs(previous) do
    if not seen[attr_name] and previous_value ~= 0 then
      add_attr_to_hero(env, attr_name, -previous_value)
    end
  end

  runtime.synced_hero_attr_bonuses = copy_bonus_pack(desired)

  local hero_attr_system = env and env.hero_attr_system
  if hero_attr_system and hero_attr_system.rebuild_derived_attrs then
    hero_attr_system.rebuild_derived_attrs(hero)
  end
end

local function pick_random_candidates(state, candidate_defs, count)
  local pool = {}
  for _, node_def in ipairs(candidate_defs or {}) do
    pool[#pool + 1] = node_def
  end

  local choices = {}
  while #choices < count and #pool > 0 do
    local total_weight = 0
    local weights = {}
    for index, candidate in ipairs(pool) do
      local weight = BondPickConfig.get_candidate_weight(candidate) or 1
      if weight < 0 then
        weight = 0
      end
      weights[index] = weight
      total_weight = total_weight + weight
    end

    local picked_index = 1
    if total_weight > 0 then
      local roll = math.random() * total_weight
      local passed = 0
      for index, weight in ipairs(weights) do
        passed = passed + weight
        if roll <= passed then
          picked_index = index
          break
        end
      end
    else
      picked_index = math.random(#pool)
    end

    local picked = table.remove(pool, picked_index)
    if picked and picked.id and string.sub(picked.id, 1, 8) == '__group_' then
      choices[#choices + 1] = build_group_choice_entry(picked, #choices + 1)
    else
      choices[#choices + 1] = build_choice_entry(state, picked, #choices + 1)
    end
  end
  return choices
end

local function collect_candidate_choice_entries(state)
  local runtime = ensure_runtime(state)
  if not runtime then
    return {}
  end

  M.rebuild_candidate_nodes(state)
  local candidate_defs = {}
  for _, node_def in ipairs(M.get_candidate_nodes(state)) do
    candidate_defs[#candidate_defs + 1] = node_def
  end
  if BondPickConfig.include_group_choices then
    for _, group_def in ipairs(get_group_choice_defs(state)) do
      candidate_defs[#candidate_defs + 1] = group_def
    end
  end

  local choice_count = BondPickConfig.choice_count or 3
  local choices = pick_random_candidates(state, candidate_defs, choice_count)

  for index, choice in ipairs(choices) do
    choice.index = index
  end
  return choices
end

function M.create_runtime()
  return {
    state_ref = nil,
    unlocked_group_ids = {},
    unlocked_node_ids = {},
    active_node_ids = {},
    pool_node_ids = {},
    candidate_node_ids = {},
    owned_node_order = {},
    line_progress = {},
    node_runtime_state = {},
    node_runtime_handles = {},
    applied_node_attr_bonuses = {},
    applied_node_runtime_bonuses = {},
    dynamic_node_attr_bonuses = {},
    dynamic_node_runtime_bonuses = {},
    synced_hero_attr_bonuses = {},
    hunter_hit_targets = {},
    arcane_empower_remaining = 0,
    current_offer_round = nil,
    current_round = nil,
    current_choices = nil,
    awaiting_choice = false,
    last_unlocked_node_id = nil,
    completed_root_sets = {},
    consumed_root_sets = {},
    fused_root_sets = {},
    completed_root_set_modes = {},
    completed_root_set_attr_bonuses = {},
    completed_root_set_runtime_bonuses = {},
  }
end

function M.get_available_group_choices(state)
  return get_group_choice_defs(state)
end

function M.get_available_group_choice_entries(state)
  local result = {}
  for index, group_def in ipairs(get_group_choice_defs(state)) do
    result[#result + 1] = build_group_choice_entry(group_def, index)
  end
  return result
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

function M.get_node_def(node_id)
  return get_node_def(node_id)
end

function M.get_slot_icon(state, slot)
  local runtime = get_runtime(state)
  if not runtime or not slot then
    return nil
  end

  local node_id = runtime.owned_node_order[slot]
  if not node_id then
    return nil
  end

  local node_def = get_node_def(node_id)
  if node_def and node_def.icon then
    return node_def.icon
  end

  if string.sub(node_id, 1, 8) == '__group_' then
    local group_def = GROUP_CHOICE_DEFS[string.sub(node_id, 9)]
    return group_def and group_def.icon or nil
  end

  return nil
end

function M.is_node_unlocked(state, node_id)
  local runtime = get_runtime(state)
  local node_def = get_node_def(node_id)
  return runtime and node_def and runtime.unlocked_node_ids[node_def.id] == true or false
end

function M.is_active(state, node_id)
  local runtime = get_runtime(state)
  local node_def = get_node_def(node_id)
  return runtime and node_def and runtime.active_node_ids[node_def.id] == true or false
end

function M.get_runtime_bonus(state, key)
  local total = M.get_total_runtime_bonuses(state)
  return total[key] or 0
end

function M.collect_route_tags(state)
  local runtime = get_runtime(state)
  local tags = {}
  if not runtime then
    return tags
  end

  for node_id in pairs(runtime.unlocked_node_ids) do
    local node_def = NODE_BY_ID[node_id]
    if node_def and node_def.parent_id == nil and ROOT_SET_DOC_META[node_id] then
      for _, tag in ipairs(node_def.route_tags or {}) do
        if string.sub(tag, 1, 5) ~= 'auto_' or is_root_set_complete(state, node_id) then
          tags[tag] = true
        end
      end
    else
      append_route_tags(tags, node_def)
    end
  end

  for root_id in pairs(runtime.completed_root_sets or {}) do
    local root_def = NODE_BY_ID[root_id]
    if root_def then
      for _, tag in ipairs(root_def.route_tags or {}) do
        tags[tag] = true
      end
    end
  end

  return tags
end

function M.has_route_tag(state, tag)
  if not tag or tag == '' then
    return false
  end
  return M.collect_route_tags(state)[tag] == true
end

function M.get_progress_count(state, node_id)
  return M.is_node_unlocked(state, node_id) and 1 or 0
end

function M.get_line_progress(state, line_id)
  local runtime = get_runtime(state)
  if not runtime or not line_id then
    return 0
  end
  return runtime.line_progress[line_id] or 0
end

function M.can_unlock_node(state, node_id)
  local runtime = get_runtime(state)
  local node_def = get_node_def(node_id)
  if not runtime or not node_def then
    return false
  end
  local root_def = get_set_root_def(node_def)
  if runtime.unlocked_node_ids[node_def.id] then
    return false
  end
  if not root_def then
    return false
  end
  local group_started = root_def.group_id and is_group_started(state, root_def.group_id)
  local allow_root = BondPickConfig.include_group_choices ~= true or group_started
  if not allow_root then
    return false
  end
  local active_tier = get_root_active_stage_tier(state, root_def.id)
  if not active_tier then
    return false
  end
  return get_node_tier(node_def) == active_tier
end

function M.get_candidate_nodes(state)
  local runtime = get_runtime(state)
  if not runtime then
    return {}
  end

  local result = {}
  for _, node_id in ipairs(ROOT_NODE_IDS) do
    if runtime.candidate_node_ids[node_id] then
      result[#result + 1] = NODE_BY_ID[node_id]
    end
  end
  for _, node_def in ipairs(NODE_LIST) do
    if not ROOT_NODE_ID_SET[node_def.id] and runtime.candidate_node_ids[node_def.id] then
      result[#result + 1] = node_def
    end
  end
  return result
end

function M.rebuild_candidate_nodes(state)
  local runtime = get_runtime(state)
  if not runtime then
    return {}
  end
  runtime.state_ref = state

  seed_active_stage_nodes_into_pool(runtime)
  local candidate_node_ids = {}
  for node_id in pairs(runtime.pool_node_ids or {}) do
    if M.can_unlock_node(state, node_id) then
      candidate_node_ids[node_id] = true
    end
  end

  runtime.candidate_node_ids = candidate_node_ids
  return candidate_node_ids
end

function M.unlock_node(state, node_id)
  local runtime = get_runtime(state)
  local node_def = get_node_def(node_id)
  if not runtime or not node_def then
    return nil, 'node_not_found'
  end
  runtime.state_ref = state
  if not M.can_unlock_node(state, node_def.id) then
    return nil, 'node_locked'
  end

  runtime.unlocked_node_ids[node_def.id] = true
  runtime.last_unlocked_node_id = node_def.id
  runtime.owned_node_order[#runtime.owned_node_order + 1] = node_def.id
  local unlock_rewards = apply_unlock_rewards(state, node_def)
  M.refresh_all_nodes(state)
  local root_def = get_set_root_def(node_def)
  if root_def then
    resolve_root_set_completion(state, root_def.id)
  end
  return node_def, unlock_rewards
end

function M.deactivate_node(state, node_id)
  local node_def = get_node_def(node_id)
  if not node_def then
    return
  end
  deactivate_node_runtime(state, node_def)
end

function M.refresh_all_nodes(state)
  local runtime = get_runtime(state)
  if not runtime then
    return
  end
  runtime.state_ref = state

  for node_id in pairs(runtime.active_node_ids) do
    local node_def = NODE_BY_ID[node_id]
    if node_def then
      deactivate_node_runtime(state, node_def)
    end
  end

  runtime.line_progress = {}
  runtime.pool_node_ids = {}
  for node_id in pairs(runtime.unlocked_node_ids) do
    local node_def = NODE_BY_ID[node_id]
    if node_def then
      set_line_progress(runtime, node_def)
      activate_node_runtime(state, node_def)
    end
  end

  seed_active_stage_nodes_into_pool(runtime)
  runtime.hunter_hit_targets = {}
  M.rebuild_candidate_nodes(state)
end

function M.get_total_attr_bonuses(state)
  local runtime = get_runtime(state)
  if not runtime then
    return {}
  end
  local result = collect_merged_bonus_packs(runtime.applied_node_attr_bonuses)
  merge_bonus_pack(result, collect_merged_bonus_packs(runtime.dynamic_node_attr_bonuses))
  apply_completed_root_set_bonus_pack(result, runtime, 'completed_root_set_attr_bonuses')
  return result
end

function M.get_total_runtime_bonuses(state)
  local runtime = get_runtime(state)
  if not runtime then
    return {}
  end
  local result = collect_merged_bonus_packs(runtime.applied_node_runtime_bonuses)
  merge_bonus_pack(result, collect_merged_bonus_packs(runtime.dynamic_node_runtime_bonuses))
  apply_completed_root_set_bonus_pack(result, runtime, 'completed_root_set_runtime_bonuses')
  return result
end

function M.refresh_effects(env)
  local state = env and env.STATE
  M.refresh_all_nodes(state)
  apply_dynamic_bonuses(env, {}, {})
  sync_attr_bonuses_to_hero(env)
end

function M.update_effects(env, dt)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  local hero_attr_system = env and env.hero_attr_system
  if not runtime or not state or not state.hero or not state.hero:is_exist() then
    return
  end

  local desired_attr = {}
  local desired_runtime = {}
  local static_runtime = collect_merged_bonus_packs(runtime.applied_node_runtime_bonuses)
  merge_bonus_pack(static_runtime, collect_merged_bonus_packs(runtime.completed_root_set_runtime_bonuses))
  local max_hp = math.max(1, hero_attr_system and hero_attr_system.get_attr(state.hero, '生命结算值') or env.y3.helper.tonumber(state.hero:get_attr('生命')) or env.y3.helper.tonumber(state.hero:get_attr('最大生命')) or 1)
  local hp_ratio = math.max(0, state.hero:get_hp() / max_hp)

  for key, value in pairs(static_runtime) do
    local attr_name = PER_SECOND_ATTR_KEYS[key]
    if attr_name and value ~= 0 then
      add_attr_to_hero(env, attr_name, value * dt)
    end
  end

  if hero_attr_system then
    hero_attr_system.rebuild_derived_attrs(state.hero)
  end

  if (static_runtime.low_hp_damage_bonus or 0) > 0 and hp_ratio <= 0.50 then
    add_bonus_value(desired_runtime, 'all_damage_bonus', static_runtime.low_hp_damage_bonus)
  end

  if (runtime.arcane_empower_remaining or 0) > 0 then
    runtime.arcane_empower_remaining = math.max(0, runtime.arcane_empower_remaining - (dt or 0))
    if runtime.arcane_empower_remaining > 0 then
      add_bonus_value(desired_runtime, 'all_damage_bonus', 0.12)
    end
  end

  apply_dynamic_bonuses(env, desired_attr, desired_runtime)
  sync_attr_bonuses_to_hero(env)
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
  local state = env and env.STATE
  local hero_attr_system = env and env.hero_attr_system
  local ratio = M.get_runtime_bonus(state, 'hunter_first_hit_ratio')
  if ratio <= 0 or not target or not env.is_active_enemy(target) then
    return
  end

  local info = env.get_enemy_runtime_info(target)
  if not env.is_boss_runtime_enemy(info) and not env.is_elite_runtime_enemy(info) then
    return
  end

  local runtime = get_runtime(state)
  if not runtime or runtime.hunter_hit_targets[target] then
    return
  end

  runtime.hunter_hit_targets[target] = true
  state.hero:damage({
    target = target,
    damage = env.round_number((hero_attr_system and hero_attr_system.get_attr(state.hero, '攻击结算值') or state.hero:get_attr('攻击') or state.hero:get_attr('物理攻击')) * ratio),
    type = env.basic_attack_damage_type,
    text_type = 'physics',
    common_attack = false,
    no_miss = true,
  })
end

function M.handle_enemy_kill(env, info)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  local hero_attr_system = env and env.hero_attr_system
  if not runtime or not state.hero or not state.hero:is_exist() then
    return
  end

  do
    local strength_on_kill = M.get_runtime_bonus(state, 'strength_on_kill')
    if strength_on_kill > 0 then
      add_attr_to_hero(env, '力量', strength_on_kill)
    end

    local agility_on_kill = M.get_runtime_bonus(state, 'agility_on_kill')
    if agility_on_kill > 0 then
      add_attr_to_hero(env, '敏捷', agility_on_kill)
    end

    local intelligence_on_kill = M.get_runtime_bonus(state, 'intelligence_on_kill')
    if intelligence_on_kill > 0 then
      add_attr_to_hero(env, '智力', intelligence_on_kill)
    end

    local attack_on_kill = env.round_number(M.get_runtime_bonus(state, 'attack_on_kill'))
    if attack_on_kill > 0 then
      add_attr_to_hero(env, '攻击', attack_on_kill)
    end

    if hero_attr_system and hero_attr_system.rebuild_derived_attrs then
      hero_attr_system.rebuild_derived_attrs(state.hero)
    end
    return
  end

  local strength_on_kill = M.get_runtime_bonus(state, 'strength_on_kill')
  if strength_on_kill > 0 then
    state.hero:add_attr('力量', strength_on_kill)
  end

  local agility_on_kill = M.get_runtime_bonus(state, 'agility_on_kill')
  if agility_on_kill > 0 then
    state.hero:add_attr('敏捷', agility_on_kill)
  end

  local intelligence_on_kill = M.get_runtime_bonus(state, 'intelligence_on_kill')
  if intelligence_on_kill > 0 then
    state.hero:add_attr('智力', intelligence_on_kill)
  end

  local attack_on_kill = env.round_number(M.get_runtime_bonus(state, 'attack_on_kill'))
  if attack_on_kill > 0 then
    if hero_attr_system then
      hero_attr_system.add_attr(state.hero, '攻击', attack_on_kill)
    else
      state.hero:add_attr('攻击', attack_on_kill)
    end
  end

  if hero_attr_system then
    hero_attr_system.rebuild_derived_attrs(state.hero)
  end
end

function M.notify_attack_skill_cast(env, skill, target)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime then
    return
  end

  if M.has_route_tag(state, 'auto_spell_burst') then
    runtime.arcane_empower_remaining = math.max(runtime.arcane_empower_remaining or 0, 3)
  end
end

function M.try_draw(env)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  if not runtime then
    return false
  end

  if runtime.awaiting_choice and runtime.current_choices and #runtime.current_choices > 0 then
    if env and env.message then
      env.message('继续当前 F 链式羁绊三选一。')
    end
    return true
  end

  if not state.resources or (state.resources.wood or 0) < BOND_DRAW_COST then
    if env and env.message then
      env.message('木材不足，无法进行链式羁绊抽取。')
    end
    return false
  end

  local choices = collect_candidate_choice_entries(state)
  if #choices == 0 then
    if env and env.message then
      env.message('当前没有可选的链式羁绊节点。')
    end
    return false
  end

  state.resources.wood = state.resources.wood - BOND_DRAW_COST
  state.bond_draw_count = (state.bond_draw_count or 0) + 1
  runtime.awaiting_choice = true
  runtime.current_choices = choices
  runtime.current_offer_round = {
    free_refresh_left = 0,
    refresh_paid_count = 0,
  }
  runtime.current_round = runtime.current_offer_round

  if env and env.message then
    env.message('链式羁绊 3选1：按 1 / 2 / 3 选择。')
  end
  return true
end

function M.refresh_choice(env)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  if not runtime or not runtime.awaiting_choice then
    return false
  end

  local choices = collect_candidate_choice_entries(state)
  if #choices == 0 then
    if env and env.message then
      env.message('当前没有可刷新的链式羁绊候选。')
    end
    return false
  end

  local round = runtime.current_offer_round or runtime.current_round or {
    free_refresh_left = 0,
    refresh_paid_count = 0,
  }

  if (round.free_refresh_left or 0) > 0 then
    round.free_refresh_left = round.free_refresh_left - 1
    if env and env.message then
      env.message(string.format('已免费刷新 F 链式羁绊三选一，剩余免费次数 %d。', round.free_refresh_left))
    end
  else
    local cost = get_refresh_cost(round.refresh_paid_count or 0)
    local wood = state.resources and state.resources.wood or 0
    if wood < cost then
      if env and env.message then
        env.message(string.format('木材不足，刷新 F 链式羁绊三选一需要 %d 木材。', cost))
      end
      return false
    end
    state.resources.wood = wood - cost
    round.refresh_paid_count = (round.refresh_paid_count or 0) + 1
    if env and env.message then
      env.message(string.format('已消耗 %d 木材刷新 F 链式羁绊三选一。', cost))
    end
  end

  runtime.current_choices = choices
  runtime.current_offer_round = round
  runtime.current_round = round
  return true
end

function M.apply_choice(env, index)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  if not runtime or not runtime.awaiting_choice then
    return false
  end

  local choice = runtime.current_choices and runtime.current_choices[index]
  if not choice then
    return false
  end

  if choice.group_id and not choice.node_id then
    local ok = unlock_group_choice(state, choice.group_id)
    if not ok then
      return false
    end

    runtime.awaiting_choice = false
    runtime.current_choices = nil
    runtime.current_offer_round = nil
    runtime.current_round = nil

    if env and env.message then
      env.message('已开启羁绊主链：' .. tostring(choice.display_name or choice.group_id) .. '。')
    end
    M.show_loadout(env)
    return true
  end

  if not choice.node_id then
    return false
  end

  local node_def, unlock_rewards_or_err = M.unlock_node(state, choice.node_id)
  if not node_def then
    if env and env.message then
      env.message('羁绊节点解锁失败：' .. tostring(unlock_rewards_or_err))
    end
    return false
  end

  runtime.awaiting_choice = false
  runtime.current_choices = nil
  runtime.current_offer_round = nil
  runtime.current_round = nil
  runtime.hunter_hit_targets = {}
  sync_attr_bonuses_to_hero(env)

  if env and env.message then
    env.message(string.format('已解锁链式羁绊：%s。', node_def.display_name))
    if unlock_rewards_or_err and #unlock_rewards_or_err > 0 then
      env.message('节点奖励：' .. table.concat(unlock_rewards_or_err, '，') .. '。')
    end
  end
  M.show_loadout(env)
  return true
end

function M.build_slot_text(state, slot)
  local runtime = get_runtime(state)
  if not runtime then
    return string.format('%d号羁绊位 空', slot)
  end

  local node_id = runtime.owned_node_order[slot]
  local node_def = node_id and NODE_BY_ID[node_id] or nil
  if not node_def and node_id and string.sub(node_id, 1, 8) == '__group_' then
    node_def = GROUP_CHOICE_DEFS[string.sub(node_id, 9)]
  end
  if not node_def then
    return string.format('%d号羁绊位 空', slot)
  end

  if node_id and string.sub(node_id, 1, 8) == '__group_' then
    return string.format(
      '%d号羁绊位 [%s]%s | %s',
      slot,
      M.get_quality_label(node_def.quality),
      node_def.display_name,
      node_def.desc or ''
    )
  end

  local summary = build_node_summary_text(node_def)
  if summary ~= '' then
    return string.format(
      '%d号羁绊位 [%s]%s | %s | %s',
      slot,
      M.get_quality_label(node_def.quality),
      node_def.display_name,
      format_line_label(node_def),
      summary
    )
  end

  return string.format(
    '%d号羁绊位 [%s]%s | %s',
    slot,
    M.get_quality_label(node_def.quality),
    node_def.display_name,
    format_line_label(node_def)
  )
end

function M.build_slot_tip_payload(state, slot)
  local runtime = get_runtime(state)
  if not runtime or not slot then
    return nil
  end

  local node_id = runtime.owned_node_order[slot]
  if not node_id then
    return nil
  end

  if string.sub(node_id, 1, 8) == '__group_' then
    return build_owned_group_tip_payload(GROUP_CHOICE_DEFS[string.sub(node_id, 9)])
  end

  return build_owned_node_tip_payload(state, NODE_BY_ID[node_id])
end

function M.build_latest_owned_tip_payload(state)
  local runtime = get_runtime(state)
  if not runtime or not runtime.owned_node_order then
    return nil
  end

  for slot = #runtime.owned_node_order, 1, -1 do
    local payload = M.build_slot_tip_payload(state, slot)
    if payload then
      return payload
    end
  end
  return nil
end

function M.show_loadout(env)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime or #runtime.owned_node_order == 0 then
    if env and env.message then
      env.message('链式羁绊栏：暂无已解锁节点。')
    end
    return
  end

  if env and env.message then
    env.message('链式羁绊栏：')
    for slot = 1, 7 do
      env.message(M.build_slot_text(state, slot))
    end
  end
end

function M.build_choice_preview_text(index, choice)
  if not choice then
    return string.format('%d. 空', index or 1)
  end

  local parts = {
    string.format('%d. %s', index or 1, choice.display_name or choice.title_text or '未命名节点'),
  }

  for _, text in ipairs(build_choice_preview_segments(choice)) do
    parts[#parts + 1] = text
  end

  return table.concat(parts, ' | ')
end

function M.build_progress_lines(state, max_lines)
  local started_lines = {}
  local frontier_lines = {}
  local result = {}

  for _, root_id in ipairs(ROOT_NODE_IDS) do
    local entry = build_root_progress_entry(state, root_id)
    if entry and entry.text and entry.text ~= '' then
      if entry.started then
        started_lines[#started_lines + 1] = entry.text
      else
        frontier_lines[#frontier_lines + 1] = entry.text
      end
    end
  end

  local limit = math.max(1, max_lines or (#started_lines + #frontier_lines))
  for _, text in ipairs(started_lines) do
    if #result >= limit then
      break
    end
    result[#result + 1] = text
  end
  for _, text in ipairs(frontier_lines) do
    if #result >= limit then
      break
    end
    result[#result + 1] = text
  end

  local remaining = (#started_lines + #frontier_lines) - #result
  if remaining > 0 then
    result[#result + 1] = string.format('其余 %d 条链路可在抽卡界面查看。', remaining)
  end
  return result
end

function M.get_root_overview_entries(state)
  local started_entries = {}
  local frontier_entries = {}

  for _, root_id in ipairs(ROOT_NODE_IDS) do
    local entry = build_root_overview_entry(state, root_id)
    if entry then
      if entry.started then
        started_entries[#started_entries + 1] = entry
      else
        frontier_entries[#frontier_entries + 1] = entry
      end
    end
  end

  local result = {}
  for _, entry in ipairs(started_entries) do
    result[#result + 1] = entry
  end
  for _, entry in ipairs(frontier_entries) do
    result[#result + 1] = entry
  end
  return result
end

function M.show_bond_progress(env)
  local state = env and env.STATE
  local lines = M.build_progress_lines(state, 10)
  if env and env.message then
    env.message('链式羁绊链路进度：')
    for _, line in ipairs(lines) do
      env.message(line)
    end
  end
end

function M.debug_grant_card(env, node_id)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  local node_def = get_node_def(node_id)
  if not runtime or not node_def then
    return false, '未知链式羁绊节点。'
  end
  if M.is_node_unlocked(state, node_def.id) then
    return false, '该链式羁绊节点已经解锁。'
  end
  if not M.can_unlock_node(state, node_def.id) then
    return false, '前置节点未满足，无法直接解锁该链式羁绊节点。'
  end

  local unlocked, err = M.unlock_node(state, node_def.id)
  if not unlocked then
    return false, '节点解锁失败：' .. tostring(err)
  end

  return true, string.format('已解锁链式羁绊节点：%s。', unlocked.display_name)
end

return M
