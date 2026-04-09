local M = {}

local BondNodes = require 'runtime.bond_nodes'
local BondTemplates = require 'runtime.bond_templates.init'

local NODE_LIST = BondNodes.list
local NODE_BY_ID = BondNodes.by_id
local LINE_BY_ID = BondNodes.by_line
local ROOT_NODE_IDS = BondNodes.root_ids
local ROOT_NODE_ID_SET = {}
local ROOT_SUBTREE_NODE_IDS = {}
local LEGACY_TAGS_BY_NODE_ID = {}

local BOND_DRAW_COST = 100
local SYSTEM_DYNAMIC_NODE_ID = '__system__'

local LEGACY_NODE_ALIASES = {
  arcane = 'bond_magic_mage',
  barrage = 'bond_archery_barrage',
  chain = 'bond_archery_moon_blade',
  fortress = 'bond_body_fortress',
  greed = 'bond_economy_greed',
  growth = 'bond_growth_strength',
  guardian = 'bond_body_life',
  hunter = 'bond_growth_demon_hunter',
  tailwind = 'bond_archery_rapid',
}

local ATTR_ALIASES_FROM_RUNTIME = {
  critical_damage_bonus = {
    ['暴击伤害'] = 100,
  },
  lifesteal_ratio = {
    ['物理吸血'] = 100,
  },
}

local RUNTIME_ALIASES = {
  bounce_count_bonus = {
    chain_bounces = 1,
  },
  elemental_damage_bonus = {
    skill_damage_bonus = 1,
  },
  multishot_bonus = {
    multishot_count = 1,
  },
  projectile_count_bonus = {
    split_count = 1,
  },
  spell_damage_bonus = {
    skill_damage_bonus = 1,
  },
}

local PER_SECOND_ATTR_KEYS = {
  agility_per_second = '敏捷',
  attack_per_second = '物理攻击',
  intelligence_per_second = '智力',
  max_hp_per_second = '最大生命',
  strength_per_second = '力量',
}

local GROUP_LABELS = {
  archery = '箭术',
  body = '体术',
  critical = '暴击',
  economy = '经济',
  growth = '成长',
  magic = '法术',
}

for _, node_id in ipairs(ROOT_NODE_IDS) do
  ROOT_NODE_ID_SET[node_id] = true
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
end

for legacy_tag, node_id in pairs(LEGACY_NODE_ALIASES) do
  LEGACY_TAGS_BY_NODE_ID[node_id] = LEGACY_TAGS_BY_NODE_ID[node_id] or {}
  LEGACY_TAGS_BY_NODE_ID[node_id][#LEGACY_TAGS_BY_NODE_ID[node_id] + 1] = legacy_tag
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

local function resolve_lookup_node_id(node_id)
  if not node_id then
    return nil
  end
  return LEGACY_NODE_ALIASES[node_id] or node_id
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

local function get_runtime(state)
  return state and state.bond_runtime or nil
end

local function get_node_def(node_id)
  local resolved_id = resolve_lookup_node_id(node_id)
  return resolved_id and NODE_BY_ID[resolved_id] or nil
end

local function append_route_tags(tags, node_def)
  if not tags or not node_def then
    return
  end

  for _, tag in ipairs(LEGACY_TAGS_BY_NODE_ID[node_def.id] or {}) do
    tags[tag] = true
  end

  for _, tag in ipairs(node_def.route_tags or {}) do
    tags[tag] = true
  end
end

local function build_attr_alias_pack(runtime_pack)
  local result = {}
  for key, value in pairs(runtime_pack or {}) do
    local aliases = ATTR_ALIASES_FROM_RUNTIME[key]
    if aliases then
      for attr_name, factor in pairs(aliases) do
        add_bonus_value(result, attr_name, value * factor)
      end
    end
  end
  return result
end

local function build_runtime_alias_pack(runtime_pack)
  local result = {}
  for key, value in pairs(runtime_pack or {}) do
    add_bonus_value(result, key, value)
    local aliases = RUNTIME_ALIASES[key]
    if aliases then
      for alias_key, factor in pairs(aliases) do
        add_bonus_value(result, alias_key, value * factor)
      end
    end
  end
  return result
end

local function build_static_attr_pack(node_def)
  local result = {}
  merge_bonus_pack(result, node_def and node_def.attr or {})
  merge_bonus_pack(result, build_attr_alias_pack(node_def and node_def.runtime or {}))
  return result
end

local function build_static_runtime_pack(node_def)
  return build_runtime_alias_pack(node_def and node_def.runtime or {})
end

local function ensure_node_state(runtime, node_id)
  runtime.node_runtime_state[node_id] = runtime.node_runtime_state[node_id] or {}
  runtime.node_runtime_handles[node_id] = runtime.node_runtime_handles[node_id] or {}
  return runtime.node_runtime_state[node_id], runtime.node_runtime_handles[node_id]
end

local function apply_static_pack(runtime, node_id, node_def)
  runtime.applied_node_attr_bonuses[node_id] = build_static_attr_pack(node_def)
  runtime.applied_node_runtime_bonuses[node_id] = build_static_runtime_pack(node_def)
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
  return state.bond_runtime
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

local function build_fallback_effect_parts(node_def)
  local parts = {}
  for key, value in pairs(node_def and node_def.attr or {}) do
    parts[#parts + 1] = string.format('%s %+g', key, value)
  end
  for key, value in pairs(build_runtime_alias_pack(node_def and node_def.runtime or {})) do
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
  if type(node_def.desc) == 'string' then
    return node_def.desc
  end
  return table.concat(build_fallback_effect_parts(node_def), '；')
end

local function get_choice_advanced_text(node_def)
  if type(node_def and node_def.desc) == 'table' and node_def.desc.advanced and node_def.desc.advanced ~= '' then
    return node_def.desc.advanced
  end
  return ''
end

local function build_choice_next_text(node_def)
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

local function build_line_progress_values(state, node_def)
  local root_def = get_line_root_def(node_def)
  local line_defs = root_def and LINE_BY_ID[root_def.line_id] or {}
  local unlocked_count = 0

  for _, def in ipairs(line_defs or {}) do
    if M.is_node_unlocked(state, def.id) then
      unlocked_count = unlocked_count + 1
    end
  end

  return string.format(
    '%s(%d/%d)',
    root_def and root_def.display_name or (node_def and node_def.display_name) or '未知羁绊',
    unlocked_count,
    #line_defs
  )
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

local function build_choice_effect_title(node_def)
  local root_def = get_line_root_def(node_def)
  local line_name = root_def and root_def.display_name or node_def and node_def.display_name or '未知羁绊'
  return string.format('激活[%s]链式效果：', line_name)
end

local function build_choice_effect_text(node_def)
  local parts = {}
  local advanced_text = trim_choice_prefix(get_choice_advanced_text(node_def))
  local next_text = build_choice_next_text(node_def)

  if advanced_text ~= '' then
    parts[#parts + 1] = advanced_text
  end
  if next_text ~= '' then
    parts[#parts + 1] = next_text
  end
  if #parts == 0 then
    parts[#parts + 1] = trim_choice_prefix(build_choice_current_text(node_def))
  end

  return table.concat(parts, '\n')
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
  local current_text = build_choice_current_text(node_def)
  local advanced_text = get_choice_advanced_text(node_def)
  local next_text = build_choice_next_text(node_def)

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
    title_text = build_line_progress_title(state, node_def),
    subtitle_text = node_def.display_name,
    progress_text = '',
    current_text = current_text,
    advanced_text = advanced_text,
    next_text = next_text,
    desc_text = build_choice_desc(node_def),
    value_text = trim_choice_prefix(current_text),
    effect_title = build_choice_effect_title(node_def),
    effect_text = build_choice_effect_text(node_def),
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

local function pick_random_candidates(state, candidate_defs, count)
  local pool = {}
  for _, node_def in ipairs(candidate_defs or {}) do
    pool[#pool + 1] = node_def
  end

  local choices = {}
  while #choices < count and #pool > 0 do
    local picked_index = math.random(#pool)
    local picked = table.remove(pool, picked_index)
    choices[#choices + 1] = build_choice_entry(state, picked, #choices + 1)
  end
  return choices
end

local function collect_candidate_choice_entries(state)
  local runtime = ensure_runtime(state)
  if not runtime then
    return {}
  end

  M.rebuild_candidate_nodes(state)
  return pick_random_candidates(state, M.get_candidate_nodes(state), 3)
end

function M.create_runtime()
  return {
    unlocked_node_ids = {},
    active_node_ids = {},
    candidate_node_ids = {},
    owned_node_order = {},
    line_progress = {},
    node_runtime_state = {},
    node_runtime_handles = {},
    applied_node_attr_bonuses = {},
    applied_node_runtime_bonuses = {},
    dynamic_node_attr_bonuses = {},
    dynamic_node_runtime_bonuses = {},
    hunter_hit_targets = {},
    arcane_empower_remaining = 0,
    current_offer_round = nil,
    current_round = nil,
    current_choices = nil,
    awaiting_choice = false,
  }
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
    append_route_tags(tags, NODE_BY_ID[node_id])
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
  if runtime.unlocked_node_ids[node_def.id] then
    return false
  end
  if not node_def.parent_id then
    return true
  end
  return runtime.unlocked_node_ids[node_def.parent_id] == true
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

  local candidate_node_ids = {}
  for _, node_id in ipairs(ROOT_NODE_IDS) do
    if M.can_unlock_node(state, node_id) then
      candidate_node_ids[node_id] = true
    end
  end

  for unlocked_node_id in pairs(runtime.unlocked_node_ids) do
    local node_def = NODE_BY_ID[unlocked_node_id]
    for _, next_id in ipairs(node_def and node_def.next_ids or {}) do
      if M.can_unlock_node(state, next_id) then
        candidate_node_ids[next_id] = true
      end
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
  if not M.can_unlock_node(state, node_def.id) then
    return nil, 'node_locked'
  end

  runtime.unlocked_node_ids[node_def.id] = true
  runtime.owned_node_order[#runtime.owned_node_order + 1] = node_def.id
  set_line_progress(runtime, node_def)
  activate_node_runtime(state, node_def)
  local unlock_rewards = apply_unlock_rewards(state, node_def)
  M.rebuild_candidate_nodes(state)
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

  for node_id in pairs(runtime.active_node_ids) do
    local node_def = NODE_BY_ID[node_id]
    if node_def then
      deactivate_node_runtime(state, node_def)
    end
  end

  runtime.line_progress = {}
  for node_id in pairs(runtime.unlocked_node_ids) do
    local node_def = NODE_BY_ID[node_id]
    if node_def then
      set_line_progress(runtime, node_def)
      activate_node_runtime(state, node_def)
    end
  end

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
  return result
end

function M.get_total_runtime_bonuses(state)
  local runtime = get_runtime(state)
  if not runtime then
    return {}
  end
  local result = collect_merged_bonus_packs(runtime.applied_node_runtime_bonuses)
  merge_bonus_pack(result, collect_merged_bonus_packs(runtime.dynamic_node_runtime_bonuses))
  return result
end

function M.refresh_effects(env)
  local state = env and env.STATE
  M.refresh_all_nodes(state)
  apply_dynamic_bonuses(env, {}, {})
end

function M.update_effects(env, dt)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime or not state or not state.hero or not state.hero:is_exist() then
    return
  end

  local desired_attr = {}
  local desired_runtime = {}
  local static_runtime = collect_merged_bonus_packs(runtime.applied_node_runtime_bonuses)
  local max_hp = math.max(1, env.y3.helper.tonumber(state.hero:get_attr('最大生命')) or 1)
  local hp_ratio = math.max(0, state.hero:get_hp() / max_hp)

  for key, value in pairs(static_runtime) do
    local attr_name = PER_SECOND_ATTR_KEYS[key]
    if attr_name and value ~= 0 then
      state.hero:add_attr(attr_name, value * dt)
    end
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
    damage = env.round_number(state.hero:get_attr('物理攻击') * ratio),
    type = env.basic_attack_damage_type,
    text_type = 'physics',
    common_attack = false,
    no_miss = true,
  })
end

function M.handle_enemy_kill(env, info)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime or not state.hero or not state.hero:is_exist() then
    return
  end

  local attack_on_kill = env.round_number(M.get_runtime_bonus(state, 'attack_on_kill'))
  if attack_on_kill > 0 then
    state.hero:add_attr('物理攻击', attack_on_kill)
  end
end

function M.notify_attack_skill_cast(env, skill, target)
  local state = env and env.STATE
  local runtime = get_runtime(state)
  if not runtime then
    return
  end

  if M.is_active(state, 'arcane') then
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
  if not choice or not choice.node_id then
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
  if not node_def then
    return string.format('%d号羁绊位 空', slot)
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
