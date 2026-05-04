local M = {}

local BondNodes = require 'data.tables.bond.bond_nodes'
local BondTipModelBuilder = require 'runtime.bond_tip_model_builder'
local BondTemplates = require 'runtime.bond_templates.init'
local BondBonusPack = require 'runtime.bond_bonus_pack'
local BondEffectRuntimeRules = require 'data.tables.bond.bond_effect_runtime_rules'
local BondModifierPool = require 'data.tables.bond.bond_modifier_pool'
local BondModifierEffects = require 'runtime.bond_modifier_effects'
local SkillRuntimeTuning = require 'data.tables.skill.skill_runtime_tuning'
local SkillVisuals = require 'data.tables.skill.skill_visuals'

local NODE_LIST = BondNodes.list
local NODE_BY_ID = BondNodes.by_id
local LINE_BY_ID = BondNodes.by_line
local ROOT_NODE_IDS = BondNodes.root_ids
local ROOT_NODE_ID_SET = {}
local ROOT_SUBTREE_NODE_IDS = {}
local ROOT_SET_PROGRESS_NODE_IDS = {}
local ROOT_STAGE_NODE_IDS = {}
local ROOT_STAGE_TIERS = {}

local BondDrawConfig = BondEffectRuntimeRules.draw or {}
local BondMiscConfig = BondEffectRuntimeRules.misc or {}
local BondPickConfig = BondEffectRuntimeRules.pick or {}

local BOND_DRAW_COST = BondDrawConfig.draw_cost or 100
local SYSTEM_DYNAMIC_NODE_ID = '__system__'

local PER_SECOND_ATTR_KEYS = BondMiscConfig.per_second_attr_keys or {}
local GROUP_LABELS = BondMiscConfig.group_labels or {}
local BOND_SKILL_LABELS = SkillRuntimeTuning and SkillRuntimeTuning.bond and SkillRuntimeTuning.bond.labels or {}
local BOND_SKILL_NAME = tostring(BOND_SKILL_LABELS.effect_name or '技能系统')
local BOND_SKILL_ACTIVATION_TEMPLATE = tostring(BOND_SKILL_LABELS.activation_template or '%s技能系统')
local BOND_SKILL_ACTIVATION_PROMPT = tostring(
  BOND_SKILL_LABELS.activation_prompt
  or '抽取并集齐同一技能的卡牌后，可自动吞噬并激活技能系统。'
)
local BOND_SKILL_ALREADY_ACTIVE_TEMPLATE = tostring(
  BOND_SKILL_LABELS.already_active_template
  or '技能系统已处于激活状态：%s。'
)
local BOND_SKILL_ACTIVE_SUCCESS_TEMPLATE = tostring(
  BOND_SKILL_LABELS.active_success_template
  or '已激活技能系统：%s。'
)

local function format_bond_skill_title(bond_name)
  local ok, text = pcall(string.format, BOND_SKILL_ACTIVATION_TEMPLATE, tostring(bond_name or '技能'))
  if ok and text and text ~= '' then
    return text
  end
  return string.format('%s%s', tostring(bond_name or '技能'), BOND_SKILL_NAME)
end

local function format_bond_skill_status(template, bond_name)
  local ok, text = pcall(string.format, tostring(template or ''), tostring(bond_name or ''))
  if ok and text and text ~= '' then
    return text
  end
  return string.format('%s：%s。', BOND_SKILL_NAME, tostring(bond_name or '未知技能'))
end

local ROOT_SET_DOC_META = {}

local is_root_set_complete
local is_group_started

local GROUP_CHOICE_ORDER = BondDrawConfig.group_choice_order or {}

local GROUP_ROOT_IDS_BY_GROUP = {}
local GROUP_CHOICE_DEFS = BondDrawConfig.group_choice_defs or {}

local function get_group_theme_name(group_id, fallback)
  return fallback or group_id or '未知分类'
end

local function get_group_choice_theme_name(group_def)
  if not group_def then
    return '未命名分组'
  end
  return get_group_theme_name(group_def.group_id, group_def.display_name)
end

local function get_group_choice_desc(group_def)
  if not group_def then
    return ''
  end
  return group_def.desc or ''
end

local function get_node_theme_name(node_def, fallback)
  if not node_def then
    return fallback or ''
  end
  return fallback or node_def.display_name or ''
end

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

local add_bonus_value = BondBonusPack.add_value
local remove_bonus_value = BondBonusPack.remove_value
local merge_bonus_pack = BondBonusPack.merge
local subtract_bonus_pack = BondBonusPack.subtract
local copy_bonus_pack = BondBonusPack.copy

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

local function is_damage_text_hidden(state)
  return state
    and state.ui_preferences
    and state.ui_preferences.hide_damage_text == true
    or false
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
  if state.skill_runtime and not state.bond_runtime then
    state.bond_runtime = state.skill_runtime
  end
  state.bond_runtime = state.bond_runtime or M.create_runtime()
  state.skill_runtime = state.bond_runtime
  state.bond_runtime.pool_node_ids = state.bond_runtime.pool_node_ids or {}
  state.bond_runtime.completed_root_sets = state.bond_runtime.completed_root_sets or {}
  state.bond_runtime.consumed_root_sets = state.bond_runtime.consumed_root_sets or {}
  state.bond_runtime.fused_root_sets = state.bond_runtime.fused_root_sets or {}
  state.bond_runtime.completed_root_set_modes = state.bond_runtime.completed_root_set_modes or {}
  state.bond_runtime.completed_root_set_attr_bonuses = state.bond_runtime.completed_root_set_attr_bonuses or {}
  state.bond_runtime.completed_root_set_runtime_bonuses = state.bond_runtime.completed_root_set_runtime_bonuses or {}
  state.bond_runtime.modifier_card_ids = state.bond_runtime.modifier_card_ids or {}
  state.bond_runtime.modifier_card_attr_bonuses = state.bond_runtime.modifier_card_attr_bonuses or {}
  state.bond_runtime.modifier_card_effect_ids = state.bond_runtime.modifier_card_effect_ids or {}
  state.bond_runtime.modifier_pool_active_effects = state.bond_runtime.modifier_pool_active_effects or {}
  state.bond_runtime.modifier_pool_active_runtime_bonuses = state.bond_runtime.modifier_pool_active_runtime_bonuses or {}
  state.bond_runtime.modifier_pool_effect_state = state.bond_runtime.modifier_pool_effect_state or {}
  if state.bond_runtime.modifier_effects_disabled == nil then
    state.bond_runtime.modifier_effects_disabled = false
  end
  state.bond_runtime.state_ref = state
  state.skill_runtime = state.bond_runtime
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
    local active_tier = runtime.state_ref and get_root_active_stage_tier(runtime.state_ref, root_id) or nil
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
    return '未知道统'
  end

  local line_defs = LINE_BY_ID[node_def.line_id] or {}
  local line_root = line_defs[1]
  local group_label = get_group_theme_name(
    node_def.group_id,
    GROUP_LABELS[node_def.group_id] or node_def.group_id
  )
  local line_label = line_root and line_root.display_name and line_root.display_name ~= ''
      and string.format('%s线', get_node_theme_name(line_root))
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
      or string.find(value, '已凑齐,解锁后续分支', 1, true)
      or (string.find(value, '已圆满', 1, true) and string.find(value, '后续道统', 1, true)) then
    return true
  end

  if string.find(value, '我要玩', 1, true)
      and string.find(value, '卡池中加入', 1, true) then
    return true
  end

  if string.find(value, '机缘已现', 1, true)
      and (string.find(value, '感应池加入', 1, true) or string.find(value, '卡池中加入', 1, true)) then
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
  local group_label = get_group_theme_name(
    root_def and root_def.group_id,
    GROUP_LABELS[root_def and root_def.group_id] or root_def and root_def.group_id
  )
  local line_label = root_def and root_def.display_name and root_def.display_name ~= ''
      and string.format('%s线', get_node_theme_name(root_def))
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

local function build_line_progress_text(state, node_def)
  local unlocked_count, required_count = build_choice_progress_values(state, node_def)
  return string.format('%d/%d', unlocked_count, required_count)
end

local function trim_choice_prefix(text)
  local trimmed = trim_inline_text(text)
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

  return get_node_theme_name(node_def)
end

local function build_choice_effect_title(state, node_def)
  if node_def and node_def.parent_id then
    return ''
  end
  local root_def = get_set_root_def(node_def)
  local line_name = root_def and get_node_theme_name(root_def) or node_def and get_node_theme_name(node_def) or '未知仙缘'
  return string.format('悟得[%s]道统真意：', line_name)
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

local function get_owned_tip_effect_text(node_def)
  local effect_text = get_choice_advanced_text(node_def)
  if effect_text ~= '' or not node_def or not node_def.parent_id then
    return effect_text
  end

  local current = node_def
  local guard = 0
  while current and current.parent_id and guard < 16 do
    current = NODE_BY_ID[current.parent_id]
    effect_text = get_choice_advanced_text(current)
    if effect_text ~= '' then
      return effect_text
    end
    guard = guard + 1
  end
  return ''
end

local function build_owned_group_tip_payload(group_def)
  if not group_def then
    return nil
  end
  local themed_name = get_group_choice_theme_name(group_def)
  local effect_text = string.format('感应后开启[%s]道统根脉。', themed_name)
  local tip_model = BondTipModelBuilder.build({
    quality_text = M.get_quality_label(group_def.quality),
    set_name_text = themed_name,
    progress_text = '(未开悟)',
    icon_res = group_def.icon,
    item_name_text = themed_name,
    bonus_text = get_group_choice_desc(group_def),
    effect_index_text = '[缘起]',
    effect_body_text = effect_text,
  })
  return {
    kind = 'bond',
    quality = group_def.quality or 'rare',
    badge_text = M.get_quality_label(group_def.quality),
    icon_res = group_def.icon,
    title_text = themed_name,
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
  local advanced_text = get_owned_tip_effect_text(node_def)
  local next_text = build_choice_next_text(node_def)
  local effect_title = build_choice_effect_title(state, set_root_def or node_def)
  local effect_text = build_choice_effect_text(set_root_def or node_def)
  local progress_text = build_line_progress_text(state, node_def)
  local tip_model = BondTipModelBuilder.build({
    quality_text = M.get_quality_label(node_def.quality),
    set_name_text = set_root_def and get_node_theme_name(set_root_def) or '',
    progress_text = progress_text ~= '' and string.format('(%s)', progress_text) or '',
    icon_res = node_def.icon,
    item_name_text = card_name_text ~= '' and card_name_text or get_node_theme_name(node_def, '未命名仙缘'),
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
    title_text = card_name_text ~= '' and card_name_text or get_node_theme_name(node_def, '未命名仙缘'),
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
      text = '道统真意：',
      color = 'gold',
      segments = {
        {
          text = '道统真意：',
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
    names[#names + 1] = get_node_theme_name(def)
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
    pretty_group_name = get_group_theme_name(root_def.group_id, GROUP_LABELS[root_def.group_id] or root_def.group_id),
    pretty_display_name = get_node_theme_name(root_def),
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

local function build_group_choice_entry(group_def, index)
  local themed_name = get_group_choice_theme_name(group_def)
  local title_text = string.format('%s (未开悟)', themed_name)
  local current_text = get_group_choice_desc(group_def)
  local effect_text = string.format('感应后开启[%s]道统根脉。', themed_name)

  return {
    index = index,
    node_id = nil,
    group_choice_id = group_def.id,
    group_id = group_def.group_id,
    display_name = group_def.display_name,
    pretty_display_name = themed_name,
    quality = group_def.quality or 'rare',
    ui_icon = group_def.icon,
    icon = group_def.icon,
    title_text = title_text,
    subtitle_text = '道统分脉',
    bond_root_name = themed_name,
    bond_root_progress_text = '未开悟',
    progress_text = '未开悟',
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

local function is_modifier_pool_enabled()
  return BondModifierPool and BondModifierPool.enabled == true
end

local function get_modifier_card(card_id)
  if not BondModifierPool or not BondModifierPool.card_by_id then
    return nil
  end
  local by_id = BondModifierPool.card_by_id
  if by_id[card_id] then
    return by_id[card_id]
  end
  local key = tostring(card_id or '')
  if key ~= '' and by_id[key] then
    return by_id[key]
  end
  local numeric = tonumber(card_id)
  if numeric and by_id[numeric] then
    return by_id[numeric]
  end
  return nil
end

local BOND_SET_ATTR_BONUSES = BondModifierEffects.SET_ATTR_BONUSES
local BOND_SET_RUNTIME_BONUSES = BondModifierEffects.SET_RUNTIME_BONUSES

local function get_modifier_cards_by_bond(bond_name)
  local normalized = BondModifierEffects.normalize_bond_name and BondModifierEffects.normalize_bond_name(bond_name) or bond_name
  return BondModifierPool and BondModifierPool.cards_by_bond and BondModifierPool.cards_by_bond[normalized] or {}
end

local function get_owned_modifier_bond_count(runtime, bond_name)
  local count = 0
  for _, card in ipairs(get_modifier_cards_by_bond(bond_name)) do
    if runtime and runtime.modifier_card_ids and runtime.modifier_card_ids[card.id] == true then
      count = count + 1
    end
  end
  return count
end

local function get_required_modifier_bond_count(bond_name)
  local cards = get_modifier_cards_by_bond(bond_name)
  return math.max(1, tonumber(cards[1] and cards[1].required_count) or #cards)
end

local function get_modifier_bond_activation_text(bond_name, fallback_text)
  local bond_key = tostring(bond_name or '')
  if bond_key ~= '' then
    for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
      if tostring(effect.bond_name or '') == bond_key then
        local effect_desc = trim_choice_prefix(effect.desc or '')
        if effect_desc ~= '' then
          return effect_desc
        end
      end
    end
  end

  local card_desc = trim_choice_prefix(fallback_text or '')
  if card_desc ~= '' then
    return card_desc
  end
  return ''
end

local function build_modifier_choice_entry(state, card, index)
  local runtime = get_runtime(state)
  local owned_count = get_owned_modifier_bond_count(runtime, card and card.bond_name)
  local total_count = get_required_modifier_bond_count(card and card.bond_name)
  local current_text = card and card.desc or ''
  local set_name = card and card.bond_name or '技能'
  local effect_text = get_modifier_bond_activation_text(card and card.bond_name, card and card.activation_desc or '')

  return {
    index = index,
    node_id = nil,
    modifier_card_id = card.id,
    display_name = card.name,
    pretty_display_name = card.name,
    quality = card.quality or 'rare',
    ui_icon = card.icon,
    icon = card.icon,
    title_text = string.format('%s (%d/%d)', set_name, owned_count, total_count),
    subtitle_text = card.name,
    bond_root_name = set_name,
    bond_root_progress_text = string.format('%d/%d', owned_count, total_count),
    progress_text = '',
    current_text = current_text,
    advanced_text = '',
    next_text = '',
    desc_text = current_text,
    value_text = trim_choice_prefix(current_text),
    effect_title = effect_text ~= '' and string.format('集齐[%s]激活：', set_name) or '',
    effect_text = effect_text,
    body_blocks = build_choice_body_blocks(state, nil, current_text, '', effect_text ~= '' and string.format('集齐[%s]激活：', set_name) or '', effect_text),
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

local function collect_modifier_pool_choice_entries(state)
  local runtime = ensure_runtime(state)
  if not runtime or not is_modifier_pool_enabled() then
    return nil
  end

  local pool = {}
  for _, card in ipairs(BondModifierPool.cards or {}) do
    if runtime.modifier_card_ids[card.id] ~= true then
      pool[#pool + 1] = card
    end
  end

  local choices = {}
  local choice_count = 4
  while #choices < choice_count and #pool > 0 do
    local picked = table.remove(pool, math.random(1, #pool))
    choices[#choices + 1] = build_modifier_choice_entry(state, picked, #choices + 1)
  end
  return choices
end

local function collect_candidate_choice_entries(state)
  return collect_modifier_pool_choice_entries(state) or {}
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
    modifier_card_ids = {},
    modifier_card_attr_bonuses = {},
    modifier_card_effect_ids = {},
    modifier_pool_active_effects = {},
    modifier_pool_active_runtime_bonuses = {},
    modifier_pool_effect_state = {},
    modifier_effects_disabled = false,
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
  if string.sub(node_id, 1, 8) == '__group_' then
    local group_def = GROUP_CHOICE_DEFS[string.sub(node_id, 9)]
    return group_def and group_def.icon or nil
  end

  local modifier_card = get_modifier_card(node_id)
  if modifier_card then
    -- 对于技能卡，先尝试从 SkillVisuals 获取图标
    local visual = SkillVisuals and SkillVisuals.get_by_bond_name and SkillVisuals.get_by_bond_name(modifier_card.bond_name or '')
      or (SkillVisuals and SkillVisuals.visual_by_bond and SkillVisuals.visual_by_bond[modifier_card.bond_name or ''])
    if visual then
      if tonumber(visual.icon_key) and tonumber(visual.icon_key) > 0 then
        return tonumber(visual.icon_key)
      elseif tonumber(visual.particle_key) and tonumber(visual.particle_key) > 0 then
        return tonumber(visual.particle_key)
      end
    end
    -- 如果 SkillVisuals 没有，使用卡片自带的图标或回退图标
    if modifier_card.icon and tonumber(modifier_card.icon) and tonumber(modifier_card.icon) > 0 then
      return tonumber(modifier_card.icon)
    end
    return 134269625 -- 回退图标
  end

  if node_def then
    -- 对于普通节点，先尝试从 SkillVisuals 获取图标
    local bond_name = node_def.visual_bond ~= '' and node_def.visual_bond or node_def.group_id
    local visual = SkillVisuals and SkillVisuals.get_by_bond_name and SkillVisuals.get_by_bond_name(bond_name or '')
      or (SkillVisuals and SkillVisuals.visual_by_bond and SkillVisuals.visual_by_bond[bond_name or ''])
    if visual then
      if tonumber(visual.icon_key) and tonumber(visual.icon_key) > 0 then
        return tonumber(visual.icon_key)
      elseif tonumber(visual.particle_key) and tonumber(visual.particle_key) > 0 then
        return tonumber(visual.particle_key)
      end
    end
    -- 如果 SkillVisuals 没有，使用节点自带的图标
    if node_def.icon and tonumber(node_def.icon) and tonumber(node_def.icon) > 0 then
      return tonumber(node_def.icon)
    end
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
  merge_bonus_pack(result, collect_merged_bonus_packs(runtime.modifier_card_attr_bonuses))
  apply_completed_root_set_bonus_pack(result, runtime, 'completed_root_set_attr_bonuses')
  return result
end

function M.get_total_runtime_bonuses(state)
  local runtime = get_runtime(state)
  if not runtime then
    return {}
  end
  if runtime.__collect_runtime_bonus_busy == true then
    return runtime.__collect_runtime_bonus_last or {}
  end
  runtime.__collect_runtime_bonus_busy = true
  local ok, result = pcall(function()
    local merged = collect_merged_bonus_packs(runtime.applied_node_runtime_bonuses)
    merge_bonus_pack(merged, collect_merged_bonus_packs(runtime.dynamic_node_runtime_bonuses))
    merge_bonus_pack(merged, collect_merged_bonus_packs(runtime.modifier_pool_active_runtime_bonuses))
    apply_completed_root_set_bonus_pack(merged, runtime, 'completed_root_set_runtime_bonuses')
    return merged
  end)
  if not ok then
    runtime.__collect_runtime_bonus_busy = false
    error(result)
  end
  runtime.__collect_runtime_bonus_last = result
  runtime.__collect_runtime_bonus_busy = false
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

  if runtime.modifier_effects_disabled ~= true then
    for effect_id, effect_state in pairs(runtime.modifier_pool_effect_state or {}) do
      if effect_state.cooldown and effect_state.cooldown > 0 then
        effect_state.cooldown = math.max(0, effect_state.cooldown - (dt or 0))
      end
      if runtime.modifier_pool_active_effects[effect_id] == true
        or BondModifierEffects.has_active_modifier_bond(runtime, effect_state.bond_name, get_modifier_cards_by_bond) then
        BondModifierEffects.trigger_modifier_periodic_effect(env, runtime, effect_state.bond_name, effect_state, dt)
      end
    end
    BondModifierEffects.trigger_modifier_card_periodic_effects(env, runtime, dt)
  end

  local desired_attr = {}
  local desired_runtime = {}
  local static_runtime = collect_merged_bonus_packs(runtime.applied_node_runtime_bonuses)
  merge_bonus_pack(static_runtime, collect_merged_bonus_packs(runtime.completed_root_set_runtime_bonuses))
  merge_bonus_pack(static_runtime, collect_merged_bonus_packs(runtime.modifier_pool_active_runtime_bonuses))
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
  local damage = env.round_number((hero_attr_system and hero_attr_system.get_attr(state.hero, '攻击结算值') or state.hero:get_attr('攻击') or state.hero:get_attr('物理攻击')) * ratio)
  if env.reserve_formula_damage then
    env.reserve_formula_damage(target, damage, {
      source = 'hunter_first_hit',
    })
  end
  state.hero:damage({
    target = target,
    damage = damage,
    type = env.basic_attack_damage_type,
    text_type = is_damage_text_hidden(state) and nil or 'physics',
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

  if runtime.modifier_effects_disabled ~= true then
    BondModifierEffects.handle_modifier_enemy_kill(env, runtime, info, get_modifier_cards_by_bond)
  end
end

function M.notify_basic_attack(env, target)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime then
    return
  end
  if runtime.__notify_basic_attack_busy == true then
    return
  end
  if runtime.modifier_effects_disabled == true then
    return
  end
  runtime.__notify_basic_attack_busy = true
  local ok, err = pcall(function()
    for _, effect_state in pairs(runtime.modifier_pool_effect_state or {}) do
      if effect_state and effect_state.bond_name
        and BondModifierEffects.has_active_modifier_bond(runtime, effect_state.bond_name, get_modifier_cards_by_bond) then
        BondModifierEffects.trigger_modifier_basic_attack_effect(env, runtime, effect_state.bond_name, target)
      end
    end
    BondModifierEffects.trigger_modifier_card_basic_attack_effects(env, runtime, target)
  end)
  runtime.__notify_basic_attack_busy = false
  if not ok then
    error(err)
  end
end

function M.notify_hero_pre_hurt(env, data)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime then
    return
  end
  if runtime.modifier_effects_disabled == true then
    return
  end
  BondModifierEffects.handle_modifier_card_pre_hurt(env, runtime, data)
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
    return true
  end

  if not state.resources or (state.resources.wood or 0) < BOND_DRAW_COST then
    return false
  end

  local choices = collect_candidate_choice_entries(state)
  if #choices == 0 then
    return false
  end

  state.resources.wood = state.resources.wood - BOND_DRAW_COST
  state.bond_draw_count = (state.bond_draw_count or 0) + 1
  state.skill_draw_count = state.bond_draw_count
  runtime.awaiting_choice = true
  runtime.current_choices = choices
  runtime.current_offer_round = {
    free_refresh_left = 0,
    refresh_paid_count = 0,
  }
  runtime.current_round = runtime.current_offer_round

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
    return false
  end

  local round = runtime.current_offer_round or runtime.current_round or {
    free_refresh_left = 0,
    refresh_paid_count = 0,
  }

  if (round.free_refresh_left or 0) > 0 then
    round.free_refresh_left = round.free_refresh_left - 1
  else
    local cost = get_refresh_cost(round.refresh_paid_count or 0)
    local wood = state.resources and state.resources.wood or 0
    if wood < cost then
      return false
    end
    state.resources.wood = wood - cost
    round.refresh_paid_count = (round.refresh_paid_count or 0) + 1
  end

  runtime.current_choices = choices
  runtime.current_offer_round = round
  runtime.current_round = round
  return true
end

local function is_modifier_bond_complete(runtime, bond_name)
  if not runtime or not bond_name or bond_name == '' or not is_modifier_pool_enabled() then
    return false
  end
  local cards = get_modifier_cards_by_bond(bond_name)
  if #cards == 0 then
    return false
  end
  local owned_count = 0
  for _, card in ipairs(cards) do
    if runtime.modifier_card_ids[card.id] ~= true then
      -- 支持表里未来配置低于卡牌总数的激活数量。
    else
      owned_count = owned_count + 1
    end
  end
  return owned_count >= get_required_modifier_bond_count(bond_name)
end

local function activate_modifier_bond_effects(state, bond_name)
  local runtime = get_runtime(state)
  if not runtime or not is_modifier_bond_complete(runtime, bond_name) then
    return {}
  end
  runtime.modifier_effects_disabled = false

  local activated_names = {}
  local effect_id = 'initial_bond_set_' .. tostring(bond_name)
  if runtime.modifier_pool_active_effects[effect_id] == true then
    return activated_names
  end

  runtime.modifier_pool_active_effects[effect_id] = true
  runtime.modifier_card_attr_bonuses[effect_id] = copy_bonus_pack(BOND_SET_ATTR_BONUSES[bond_name] or {})
  runtime.modifier_pool_active_runtime_bonuses[effect_id] = copy_bonus_pack(BOND_SET_RUNTIME_BONUSES[bond_name] or {})
  local effect_state = BondModifierEffects.ensure_effect_state(runtime, bond_name)
  effect_state.cooldown = 0
  effect_state.counter = 0
  effect_state.elapsed = 0
  effect_state.__periodic_ready_on_gain = nil
  activated_names[#activated_names + 1] = bond_name

  for _, card in ipairs(get_modifier_cards_by_bond(bond_name)) do
    runtime.consumed_root_sets[card.id] = true
  end
  return activated_names
end

local function clear_active_modifier_bond_effects(runtime)
  if not runtime then
    return
  end
  if BondModifierEffects and BondModifierEffects.clear_runtime_status_effects then
    BondModifierEffects.clear_runtime_status_effects(runtime)
  end
  -- N0 单技能/零技能切换需要真正互斥：清空已激活效果，同时重置技能卡运行时态。
  runtime.modifier_pool_active_effects = {}
  runtime.modifier_card_attr_bonuses = {}
  runtime.modifier_pool_active_runtime_bonuses = {}
  runtime.modifier_pool_effect_state = {}
  runtime.modifier_card_ids = {}
  runtime.modifier_card_effect_ids = {}
  runtime.modifier_card_effect_state = {}
  runtime.modifier_card_effect_custom_state = {}
  runtime.consumed_root_sets = {}
  runtime.modifier_effects_disabled = true
end

local function grant_modifier_card_to_runtime(runtime, card)
  if not runtime or not card or runtime.modifier_card_ids[card.id] == true then
    return false
  end

  runtime.modifier_card_ids[card.id] = true
  runtime.modifier_card_attr_bonuses[card.id] = copy_bonus_pack(card.attr_pack or {})
  if card.extra_skill_desc and card.extra_skill_desc ~= '' and card.extra_skill_desc ~= '无' then
    runtime.modifier_card_effect_ids[card.id] = true
    BondModifierEffects.ensure_effect_state(runtime, card.bond_name)
  end
  runtime.owned_node_order[#runtime.owned_node_order + 1] = card.id
  runtime.last_unlocked_node_id = card.id
  return true
end

local function apply_modifier_pool_choice(env, choice)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  local card = choice and get_modifier_card(choice.modifier_card_id) or nil
  if not runtime or not card then
    return false
  end

  if runtime.modifier_card_ids[card.id] == true then
    return false
  end

  grant_modifier_card_to_runtime(runtime, card)
  sync_attr_bonuses_to_hero(env)

  local activated_names = activate_modifier_bond_effects(state, card.bond_name)
  if #activated_names > 0 then
    sync_attr_bonuses_to_hero(env)
  end

  runtime.awaiting_choice = false
  runtime.current_choices = nil
  runtime.current_offer_round = nil
  runtime.current_round = nil
  runtime.hunter_hit_targets = {}

  return true
end

local function trim_debug_text(text)
  return tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function resolve_modifier_card(card_ref)
  local key = trim_debug_text(card_ref)
  if key == '' then
    return nil
  end

  local by_id = get_modifier_card(key)
  if by_id then
    return by_id
  end

  local lower_key = string.lower(key)
  for _, card in ipairs(BondModifierPool.cards or {}) do
    if card.name == key or string.lower(tostring(card.id or '')) == lower_key then
      return card
    end
  end
  return nil
end

local function resolve_modifier_bond_name(raw_name)
  local target = trim_debug_text(raw_name)
  target = BondModifierEffects.normalize_bond_name and BondModifierEffects.normalize_bond_name(target) or target
  if target == '' then
    return nil
  end
  if BondModifierPool.cards_by_bond and BondModifierPool.cards_by_bond[target] then
    return target
  end
  for bond_name in pairs(BondModifierPool.cards_by_bond or {}) do
    if tostring(bond_name) == target then
      return bond_name
    end
  end
  return nil
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

  if choice.modifier_card_id then
    local ok = apply_modifier_pool_choice(env, choice)
    if ok then
      M.show_loadout(env)
    end
    return ok
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
      env.message('已开启仙缘道统：' .. tostring(choice.pretty_display_name or choice.display_name or choice.group_id) .. '。')
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
      env.message('仙缘节点解锁失败：' .. tostring(unlock_rewards_or_err))
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
    env.message(string.format('已参悟仙缘：%s。', get_node_theme_name(node_def)))
    if type(unlock_rewards_or_err) == 'table' and #unlock_rewards_or_err > 0 then
      env.message('节点奖励：' .. table.concat(unlock_rewards_or_err, '，') .. '。')
    end
  end
  M.show_loadout(env)
  return true
end

function M.build_slot_text(state, slot)
  local runtime = get_runtime(state)
  if not runtime then
    return string.format('%d号仙缘位 空', slot)
  end

  local node_id = runtime.owned_node_order[slot]
  local node_def = node_id and NODE_BY_ID[node_id] or nil
  local modifier_card = node_id and get_modifier_card(node_id) or nil
  if modifier_card then
    return string.format(
      '%d号仙缘位 [技能卡]%s | %s',
      slot,
      tostring(modifier_card.name or modifier_card.id),
      tostring(modifier_card.desc or '')
    )
  end
  if not node_def and node_id and string.sub(node_id, 1, 8) == '__group_' then
    node_def = GROUP_CHOICE_DEFS[string.sub(node_id, 9)]
  end
  if not node_def then
    return string.format('%d号仙缘位 空', slot)
  end

  if node_id and string.sub(node_id, 1, 8) == '__group_' then
    return string.format(
      '%d号仙缘位 [%s]%s | %s',
      slot,
      M.get_quality_label(node_def.quality),
      get_group_choice_theme_name(node_def),
      get_group_choice_desc(node_def)
    )
  end

  local summary = build_node_summary_text(node_def)
  if summary ~= '' then
    return string.format(
      '%d号仙缘位 [%s]%s | %s | %s',
      slot,
      M.get_quality_label(node_def.quality),
      get_node_theme_name(node_def),
      format_line_label(node_def),
      summary
    )
  end

  return string.format(
    '%d号仙缘位 [%s]%s | %s',
    slot,
    M.get_quality_label(node_def.quality),
    get_node_theme_name(node_def),
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

  local modifier_card = get_modifier_card(node_id)
  if modifier_card then
    local effect_text = get_modifier_bond_activation_text(modifier_card.bond_name, modifier_card.activation_desc or '')
    local required_count = get_required_modifier_bond_count(modifier_card.bond_name)
    local tip_model = BondTipModelBuilder.build({
      quality_text = '技能卡',
      set_name_text = modifier_card.bond_name or '',
      progress_text = string.format('%d/%d', get_owned_modifier_bond_count(runtime, modifier_card.bond_name), required_count),
      icon_res = modifier_card.icon,
      item_name_text = modifier_card.name or '技能卡牌',
      current_text = modifier_card.desc or '',
      effect_body_text = string.format('集齐%d个%s卡牌自动吞噬', required_count, tostring(modifier_card.bond_name or '同技能')),
      set_title_text = format_bond_skill_title(modifier_card.bond_name),
      effect_text = effect_text,
    })
    return {
      kind = 'bond',
      quality = modifier_card.quality or 'rare',
      badge_text = '技能卡',
      icon_res = modifier_card.icon,
      title_text = modifier_card.name or '技能卡牌',
      bonus_lines = tip_model.bonus_lines,
      effect_area_bonus_count = math.min(3, #tip_model.bonus_lines),
      tip_model = tip_model,
    }
  end

  if string.sub(node_id, 1, 8) == '__group_' then
    local group_payload = build_owned_group_tip_payload(GROUP_CHOICE_DEFS[string.sub(node_id, 9)])
    if group_payload then
      return group_payload
    end
    local group_name = string.sub(node_id, 9)
    return {
      kind = 'bond',
      quality = 'rare',
      badge_text = '技能组',
      icon_res = nil,
      title_text = group_name ~= '' and group_name or '技能组',
      bonus_lines = {},
      effect_area_bonus_count = 0,
      tip_model = {
        quality_text = '技能组',
        set_name_text = group_name ~= '' and group_name or '技能组',
        progress_text = '',
        item_name_text = group_name ~= '' and group_name or '技能组',
        effect_body_text = '当前技能组暂无可展示说明。',
        set_title_text = format_bond_skill_title(group_name),
        set_body_lines = {},
        bonus_lines = {},
      },
    }
  end

  local node_payload = build_owned_node_tip_payload(state, NODE_BY_ID[node_id])
  if node_payload then
    return node_payload
  end

  return {
    kind = 'bond',
    quality = 'rare',
    badge_text = '技能',
    icon_res = M.get_slot_icon(state, slot),
    title_text = tostring(node_id),
    bonus_lines = {},
    effect_area_bonus_count = 0,
    tip_model = {
      quality_text = '技能',
      set_name_text = '',
      progress_text = '',
      item_name_text = tostring(node_id),
      effect_body_text = '当前技能节点暂无可展示说明。',
      set_title_text = format_bond_skill_title('技能'),
      set_body_lines = {},
      bonus_lines = {},
    },
  }
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
  return
end

end

function M.build_choice_preview_text(index, choice)
  if not choice then
    return string.format('%d. 空', index or 1)
  end

  local parts = {
    string.format('%d. %s', index or 1, choice.pretty_display_name or choice.display_name or choice.title_text or '未命名节点'),
  }

  for _, text in ipairs(build_choice_preview_segments(choice)) do
    parts[#parts + 1] = text
  end

  return table.concat(parts, ' | ')
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

function M.build_bond_swallow_panel_model(state, selected_root_index)
  local runtime = ensure_runtime(state)
  if not runtime then
    return nil
  end

  if is_modifier_pool_enabled() then
    local root_entries = {}
    local source_effects = BondModifierPool.activation_effects or {}
    for index, effect in ipairs(source_effects) do
      local bond_name = effect.bond_name or effect.name or ''
      local cards = get_modifier_cards_by_bond(bond_name)
      if bond_name ~= '' and #cards > 0 then
        local owned_count = get_owned_modifier_bond_count(runtime, bond_name)
        local required_count = get_required_modifier_bond_count(bond_name)
        -- 运行时激活状态统一使用 initial_bond_set_<bond_name>，避免和配置表 effect.id 混用导致“已激活但未显示吞噬”。
        local effect_id = 'initial_bond_set_' .. tostring(bond_name)
        local consumed = runtime.modifier_pool_active_effects
          and runtime.modifier_pool_active_effects[effect_id] == true
          or false
        local completed = owned_count >= required_count
        root_entries[#root_entries + 1] = {
          index = index,
          root_id = effect_id,
          source_effect_id = effect.id,
          bond_name = bond_name,
          display_name = bond_name,
          pretty_display_name = bond_name,
          title = bond_name,
          icon = effect.icon or cards[1].icon,
          quality = effect.quality or cards[1].quality or 'SR',
          owned_count = owned_count,
          unlocked_count = owned_count,
          required_count = required_count,
          total_count = #cards,
          progress_text = string.format('%d/%d', owned_count, required_count),
          consumed = consumed,
          completed = completed,
          started = owned_count > 0,
          effect_text = effect.desc or cards[1].activation_desc or '',
          summary = cards[1].extra_skill_desc or '',
        }
      end
    end

    if #root_entries == 0 then
      return nil
    end

    local selected_index = math.max(1, math.floor(tonumber(selected_root_index) or 1))
    if selected_index > #root_entries then
      selected_index = 1
    end
    local selected = root_entries[selected_index]
    local selected_cards = get_modifier_cards_by_bond(selected and selected.bond_name)
    local effect_id = selected and selected.root_id or ''
    local consumed = runtime.modifier_pool_active_effects
      and runtime.modifier_pool_active_effects[effect_id] == true
      or false
	    local card_entries = {}
	    for index, card in ipairs(selected_cards) do
	      local unlocked = runtime.modifier_card_ids and runtime.modifier_card_ids[card.id] == true or false
	      local activation_text = get_modifier_bond_activation_text(card.bond_name, card.activation_desc or '')
	      local special_text = tostring(card.extra_skill_desc or '')
	      local display_effect_text = special_text ~= '' and special_text ~= '无' and special_text or activation_text
	      local display_effect_body = ''
	      if display_effect_text ~= activation_text and activation_text ~= '' then
	        display_effect_body = string.format('集齐[%s]激活：%s', tostring(card.bond_name or '技能'), activation_text)
	      end
	      local tip_model = BondTipModelBuilder.build({
	        quality_text = '技能卡',
	        set_name_text = card.bond_name or '',
	        progress_text = selected and selected.progress_text or '',
	        icon_res = card.icon,
	        item_name_text = card.name or '技能卡牌',
	        current_text = card.desc or '',
	        effect_text = display_effect_text,
	        effect_body_text = display_effect_body,
	      })
	      card_entries[#card_entries + 1] = {
        index = index,
        modifier_card_id = card.id,
        display_name = card.name,
        pretty_display_name = card.name,
        title = card.name,
        subtitle_text = card.name,
        icon = card.icon,
        ui_icon = card.icon,
        quality = card.quality or 'SR',
        unlocked = unlocked,
        consumed = consumed,
        current_text = card.desc or '',
	        desc_text = card.desc or '',
	        value_text = card.desc or '',
	        advanced_text = display_effect_text,
	        effect_title = display_effect_text ~= '' and '特殊效果：' or '',
	        effect_text = display_effect_text,
	        bond_root_name = card.bond_name,
        bond_root_progress_text = selected and selected.progress_text or '',
        title_text = string.format('%s (%s)', card.bond_name or '技能', selected and selected.progress_text or '0/0'),
        tip_model = tip_model,
      }
    end

    local consumed_count = 0
    for _, entry in ipairs(root_entries) do
      if entry.consumed then
        consumed_count = consumed_count + 1
      end
    end

    local status = '未收集'
    if consumed then
      status = '已吞噬'
    elseif selected and selected.completed then
      status = '已集齐'
    elseif selected and selected.owned_count and selected.owned_count > 0 then
      status = '收集中'
    end

    local detail_lines = {}
    if selected and selected.effect_text and selected.effect_text ~= '' then
      detail_lines[#detail_lines + 1] = selected.effect_text
    end
    if selected and selected.summary and selected.summary ~= '' and selected.summary ~= '无' then
      detail_lines[#detail_lines + 1] = selected.summary
    end
    if #detail_lines == 0 then
      detail_lines[#detail_lines + 1] = BOND_SKILL_ACTIVATION_PROMPT
    end

    return {
      selected_root_index = selected_index,
      total_consumed = consumed_count,
      root_entries = root_entries,
      card_entries = card_entries,
      detail = {
        title = selected and selected.pretty_display_name or '未选择技能',
        status = status,
        progress = selected and selected.progress_text or '0/0',
        body = table.concat(detail_lines, '\n'),
      },
    }
  end

  return nil
end

function M.debug_grant_card(env, node_id)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  local node_def = get_node_def(node_id)
  if not runtime or not node_def then
    return false, '未知仙缘节点。'
  end
  if M.is_node_unlocked(state, node_def.id) then
    return false, '该仙缘节点已经参悟。'
  end
  if not M.can_unlock_node(state, node_def.id) then
    return false, '前置缘法未满足，无法直接参悟该仙缘节点。'
  end

  local unlocked, err = M.unlock_node(state, node_def.id)
  if not unlocked then
    return false, '节点解锁失败：' .. tostring(err)
  end

  return true, string.format('已参悟仙缘节点：%s。', get_node_theme_name(unlocked))
end

function M.debug_grant_modifier_card(env, card_ref)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  local card = resolve_modifier_card(card_ref)
  if not runtime or not card then
    return false, '未知技能卡（请传 card_id 或卡名）。'
  end
  if runtime.modifier_card_ids[card.id] == true then
    return false, string.format('该技能卡已拥有：%s。', tostring(card.name or card.id))
  end

  grant_modifier_card_to_runtime(runtime, card)
  sync_attr_bonuses_to_hero(env)
  return true, string.format('已获得单卡效果：%s（%s）。', tostring(card.name or card.id), tostring(card.bond_name or '未知技能'))
end

function M.debug_activate_modifier_bond(env, bond_name, grant_missing_cards)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  local resolved_bond_name = resolve_modifier_bond_name(bond_name)
  if not runtime or not resolved_bond_name then
    return false, '未知技能名（请传 bonds_init 中的技能所属）。'
  end
  runtime.modifier_effects_disabled = false

  local granted_count = 0
  if grant_missing_cards == true then
    for _, card in ipairs(get_modifier_cards_by_bond(resolved_bond_name)) do
      if grant_modifier_card_to_runtime(runtime, card) then
        granted_count = granted_count + 1
      end
    end
  end

  local effect_id = 'initial_bond_set_' .. tostring(resolved_bond_name)
  if runtime.modifier_pool_active_effects[effect_id] == true then
    if granted_count > 0 then
      sync_attr_bonuses_to_hero(env)
    end
    if env and env.setup_basic_attack_ability then
      env.setup_basic_attack_ability()
    end
    if env and env.sync_basic_attack_ability then
      env.sync_basic_attack_ability()
    end
    return true, format_bond_skill_status(BOND_SKILL_ALREADY_ACTIVE_TEMPLATE, resolved_bond_name)
  end

  local activated_names = activate_modifier_bond_effects(state, resolved_bond_name)
  if #activated_names > 0 then
    sync_attr_bonuses_to_hero(env)
    if env and env.setup_basic_attack_ability then
      env.setup_basic_attack_ability()
    end
    if env and env.sync_basic_attack_ability then
      env.sync_basic_attack_ability()
    end
    return true, format_bond_skill_status(BOND_SKILL_ACTIVE_SUCCESS_TEMPLATE, resolved_bond_name)
  end

  local owned_count = get_owned_modifier_bond_count(runtime, resolved_bond_name)
  local need_count = get_required_modifier_bond_count(resolved_bond_name)
  return false, string.format(
    '技能未集齐，无法激活：%s（%d/%d）。',
    tostring(resolved_bond_name),
    owned_count,
    need_count
  )
end

function M.debug_activate_single_modifier_bond(env, bond_name, grant_missing_cards)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  local resolved_bond_name = resolve_modifier_bond_name(bond_name)
  if not runtime or not resolved_bond_name then
    return false, '未知技能名（请传 bonds_init 中的技能所属）。'
  end

  clear_active_modifier_bond_effects(runtime)
  runtime.modifier_effects_disabled = false
  sync_attr_bonuses_to_hero(env)

  return M.debug_activate_modifier_bond(env, resolved_bond_name, grant_missing_cards)
end

function M.debug_clear_active_modifier_bonds(env)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  if not runtime then
    return false, '技能运行时未初始化。'
  end

  clear_active_modifier_bond_effects(runtime)
  sync_attr_bonuses_to_hero(env)
  return true, '已清空当前激活技能与技能卡效果。'
end

-- skill_* 兼容别名：对外逐步迁移到“技能系统”命名。
M.try_skill_draw = M.try_draw
M.refresh_skill_choice = M.refresh_choice
M.apply_skill_choice = M.apply_choice
M.build_skill_slot_text = M.build_slot_text
M.build_skill_choice_preview_text = M.build_choice_preview_text
M.build_skill_swallow_panel_model = M.build_bond_swallow_panel_model
M.debug_activate_modifier_skill = M.debug_activate_modifier_bond
M.debug_activate_single_modifier_skill = M.debug_activate_single_modifier_bond
M.debug_clear_active_modifier_skills = M.debug_clear_active_modifier_bonds

return M



