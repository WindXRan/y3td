local M = {}

local BondTipModelBuilder = require 'runtime.bond_tip_model_builder'
local BondBonusPack = require 'runtime.bond_bonus_pack'
local BondEffectRuntimeRules = require 'data.tables.bond.bond_effect_runtime_rules'
local BondModifierPool = require 'data.tables.bond.bond_modifier_pool'
local BondModifierEffects = require 'runtime.bond_modifier_effects'
local SkillRuntimeTuning = require 'data.tables.skill.skill_runtime_tuning'
local SkillVisuals = require 'data.tables.skill.skill_visuals'
local TipBlockStyle = require 'data.tables.tip_block_style'
local IconResolver = require 'data.tables.icon_resolver'

local BondDrawConfig = BondEffectRuntimeRules.draw or {}
local BondMiscConfig = BondEffectRuntimeRules.misc or {}

local BOND_DRAW_COST = BondDrawConfig.draw_cost or 100
local SYSTEM_DYNAMIC_NODE_ID = '__system__'
local BOND_MAX_SLOTS = 8

local PER_SECOND_ATTR_KEYS = BondMiscConfig.per_second_attr_keys or {}
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

-- 默认回退图标ID
local DEFAULT_BOND_ICON = 131414

local function resolve_display_icon(...)
  return IconResolver.pick(...)
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



local function ensure_runtime(state)
  if not state then
    return nil
  end
  if state.skill_runtime and not state.bond_runtime then
    state.bond_runtime = state.skill_runtime
  end
  state.bond_runtime = state.bond_runtime or M.create_runtime()
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

  -- 初始化时标记为已处理，但不发放任何初始羁绊
  local runtime = state.bond_runtime
  runtime._initialized_initial_cards = true

  return state.bond_runtime
end

local function trim_inline_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  return (text:gsub('[。；;，,%s]+$', ''))
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



local function trim_choice_prefix(text)
  local trimmed = trim_inline_text(text)
  return trim_inline_text(trimmed)
end

local function get_node_def(node_id)
  return nil
end

local function append_route_tags(tags, node_def)
end

local function apply_completed_root_set_bonus_pack(target, runtime, field_name)
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

-- choice entry 工厂：保证所有 choice entry 返回统一的字段结构。
local CHOICE_ENTRY_DEFAULTS = {
  index = 0,
  node_id = nil,
  display_name = '',
  pretty_display_name = '',
  quality = 'rare',
  icon_res = nil,
  ui_icon = nil,
  icon = nil,
  bg = nil,
  title_text = '',
  subtitle_text = '',
  bond_root_name = '',
  bond_root_progress_text = '',
  progress_text = '',
  current_text = '',
  advanced_text = '',
  next_text = '',
  desc_text = '',
  value_text = '',
  effect_title = '',
  effect_text = '',
  body_blocks = {},
  effect_color_mode = 'auto',
}

local function new_choice_entry(fields)
  local entry = {}
  for k, v in pairs(CHOICE_ENTRY_DEFAULTS) do
    entry[k] = v
  end
  if fields then
    for k, v in pairs(fields) do
      entry[k] = v
    end
  end
  return entry
end



local function is_modifier_pool_enabled()
  return BondModifierPool and BondModifierPool.enabled == true
end

local function is_bond_slots_full(runtime)
  if not runtime then
    return false
  end
  return #(runtime.owned_node_order or {}) >= BOND_MAX_SLOTS
end

local function get_owned_bond_entries(state)
  local runtime = ensure_runtime(state)
  if not runtime then
    return {}
  end
  local entries = {}
  for slot, node_id in ipairs(runtime.owned_node_order or {}) do
    local card = get_modifier_card(node_id)
    if card then
      local bond_name = card.bond_name or '未知技能'
      local icon = resolve_display_icon(card.icon, card.bg)
      entries[#entries + 1] = {
        slot = slot,
        node_id = node_id,
        card = card,
        bond_name = bond_name,
        icon = icon,
        display_name = card.name or bond_name,
        quality = card.quality or 'rare',
      }
    end
  end
  return entries
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
  local normalized = BondModifierEffects.normalize_bond_name and BondModifierEffects.normalize_bond_name(bond_name) or
      bond_name
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
  local effect_title = effect_text ~= '' and string.format('集齐[%s]激活：', set_name) or ''

  return new_choice_entry({
    index = index,
    modifier_card_id = card.id,
    display_name = card.name,
    pretty_display_name = card.name,
    quality = card.quality or 'rare',
    icon_res = resolve_display_icon(card.icon, card.bg),
    ui_icon = resolve_display_icon(card.icon, card.bg),
    icon = resolve_display_icon(card.icon, card.bg),
    bg = card.bg,
    title_text = string.format('%s (%d/%d)', set_name, owned_count, total_count),
    subtitle_text = card.name,
    bond_root_name = set_name,
    bond_root_progress_text = string.format('%d/%d', owned_count, total_count),
    current_text = current_text,
    desc_text = current_text,
    value_text = trim_choice_prefix(current_text),
    effect_title = effect_title,
    effect_text = effect_text,
    body_blocks = build_choice_body_blocks(state, nil, current_text, '', effect_title, effect_text),
  })
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

function M.get_slot_icon(state, slot)
  local runtime = ensure_runtime(state)
  if not runtime or not slot then
    return nil
  end

  local node_id = runtime.owned_node_order[slot]
  if not node_id then
    return nil
  end

  local modifier_card = get_modifier_card(node_id)
  if modifier_card then
    local visual = SkillVisuals and SkillVisuals.get_by_bond_name and
        SkillVisuals.get_by_bond_name(modifier_card.bond_name or '')
        or (SkillVisuals and SkillVisuals.visual_by_bond and SkillVisuals.visual_by_bond[modifier_card.bond_name or ''])
    return resolve_display_icon(
      modifier_card.icon,
      visual and visual.icon_key or nil,
      modifier_card.bg,
      visual and visual.particle_key or nil,
      DEFAULT_BOND_ICON
    )
  end

  return nil
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
  return tags
end

function M.has_route_tag(state, tag)
  if not tag or tag == '' then
    return false
  end
  return M.collect_route_tags(state)[tag] == true
end



function M.rebuild_candidate_nodes(state)
  local runtime = get_runtime(state)
  if not runtime then
    return {}
  end
  runtime.state_ref = state
  runtime.candidate_node_ids = {}
  return {}
end



function M.refresh_all_nodes(state)
  local runtime = get_runtime(state)
  if not runtime then
    return
  end
  runtime.state_ref = state
  runtime.hunter_hit_targets = {}
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
  local max_hp = math.max(1,
    hero_attr_system and hero_attr_system.get_attr(state.hero, '生命结算值') or
    env.y3.helper.tonumber(state.hero:get_attr('生命')) or env.y3.helper.tonumber(state.hero:get_attr('最大生命')) or 1)
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
  local damage = env.round_number((hero_attr_system and hero_attr_system.get_attr(state.hero, '攻击结算值') or state.hero:get_attr('攻击') or state.hero:get_attr('物理攻击')) *
    ratio)
  if env.reserve_formula_damage then
    env.reserve_formula_damage(target, damage, {
      source = 'hunter_first_hit',
    })
  end
  state.hero:damage({
    target = target,
    damage = damage,
    type = env.basic_attack_damage_type,
    source_unit = state.hero,
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

  for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
    if effect.bond_name == bond_name then
      local activation_card = get_modifier_card(effect.id)
      if activation_card and activation_card.ghost_card == true then
        runtime.modifier_card_ids[activation_card.id] = true
        runtime.modifier_card_attr_bonuses[activation_card.id] = copy_bonus_pack(activation_card.attr_pack or {})
        if activation_card.extra_skill_desc and activation_card.extra_skill_desc ~= '' and activation_card.extra_skill_desc ~= '无' then
          runtime.modifier_card_effect_ids[activation_card.id] = true
          BondModifierEffects.ensure_effect_state(runtime, activation_card.bond_name)
        end
      end
      break
    end
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

  if is_bond_slots_full(runtime) then
    runtime.awaiting_bond_replacement = true
    runtime.pending_bond_replacement_card = card
    runtime.pending_bond_replacement_choice = choice
    runtime.bond_replacement_options = get_owned_bond_entries(state)
    return 'replace'
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

function M.apply_bond_replacement(env, replace_slot)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  if not runtime or not runtime.awaiting_bond_replacement then
    return false
  end

  local card = runtime.pending_bond_replacement_card
  local old_node_id = runtime.bond_replacement_options and runtime.bond_replacement_options[replace_slot] and runtime.bond_replacement_options[replace_slot].node_id

  if not old_node_id then
    return false
  end

  local old_card = get_modifier_card(old_node_id)
  if old_card then
    runtime.modifier_card_ids[old_node_id] = nil
    runtime.modifier_card_attr_bonuses[old_node_id] = nil
    runtime.modifier_card_effect_ids[old_node_id] = nil
  end

  local new_owned = {}
  for _, owned_id in ipairs(runtime.owned_node_order or {}) do
    if owned_id ~= old_node_id then
      new_owned[#new_owned + 1] = owned_id
    end
  end
  new_owned[#new_owned + 1] = card.id
  runtime.owned_node_order = new_owned

  runtime.modifier_card_ids[card.id] = true
  runtime.modifier_card_attr_bonuses[card.id] = copy_bonus_pack(card.attr_pack or {})
  if card.extra_skill_desc and card.extra_skill_desc ~= '' and card.extra_skill_desc ~= '无' then
    runtime.modifier_card_effect_ids[card.id] = true
    BondModifierEffects.ensure_effect_state(runtime, card.bond_name)
  end
  runtime.last_unlocked_node_id = card.id

  runtime.awaiting_bond_replacement = false
  runtime.pending_bond_replacement_card = nil
  runtime.pending_bond_replacement_choice = nil
  runtime.bond_replacement_options = nil

  runtime.awaiting_choice = false
  runtime.current_choices = nil
  runtime.current_offer_round = nil
  runtime.current_round = nil
  runtime.hunter_hit_targets = {}

  sync_attr_bonuses_to_hero(env)
  local activated_names = activate_modifier_bond_effects(state, card.bond_name)
  if #activated_names > 0 then
    sync_attr_bonuses_to_hero(env)
  end

  return true
end

function M.cancel_bond_replacement(env)
  local state = env and env.STATE
  local runtime = ensure_runtime(state)
  if not runtime then
    return false
  end

  runtime.awaiting_bond_replacement = false
  runtime.pending_bond_replacement_card = nil
  runtime.pending_bond_replacement_choice = nil
  runtime.bond_replacement_options = nil

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
    local result = apply_modifier_pool_choice(env, choice)
    if result == 'replace' then
      return 'replace'
    end
    if result then
      M.show_loadout(env)
    end
    return result
  end

  return false
end

function M.build_slot_text(state, slot)
  local runtime = get_runtime(state)
  if not runtime then
    return string.format('%d号仙缘位 空', slot)
  end

  local node_id = runtime.owned_node_order[slot]
  local modifier_card = node_id and get_modifier_card(node_id) or nil
  if modifier_card then
    return string.format(
      '%d号仙缘位 [技能卡]%s | %s',
      slot,
      tostring(modifier_card.name or modifier_card.id),
      tostring(modifier_card.desc or '')
    )
  end

  return string.format('%d号仙缘位 空', slot)
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
    local visual = SkillVisuals and SkillVisuals.get_by_bond_name and
        SkillVisuals.get_by_bond_name(modifier_card.bond_name or '')
        or (SkillVisuals and SkillVisuals.visual_by_bond and SkillVisuals.visual_by_bond[modifier_card.bond_name or ''])
    local resolved_icon = resolve_display_icon(
      modifier_card.icon,
      visual and visual.icon_key or nil,
      modifier_card.bg,
      visual and visual.particle_key or nil,
      DEFAULT_BOND_ICON
    )

    local effect_text = get_modifier_bond_activation_text(modifier_card.bond_name, modifier_card.activation_desc or '')
    local required_count = get_required_modifier_bond_count(modifier_card.bond_name)
    local tip_model = BondTipModelBuilder.build({
      quality_text = '技能卡',
      set_name_text = modifier_card.bond_name or '',
      progress_text = string.format('%d/%d', get_owned_modifier_bond_count(runtime, modifier_card.bond_name),
        required_count),
      icon_res = resolved_icon,
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
      icon_res = resolved_icon,
      title_text = modifier_card.name or '技能卡牌',
      bonus_lines = tip_model.bonus_lines,
      effect_area_bonus_count = math.min(3, #tip_model.bonus_lines),
      tip_model = tip_model,
    }
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
      local resolved_icon = resolve_display_icon(card.icon, card.bg)
      local tip_model = BondTipModelBuilder.build({
        quality_text = '技能卡',
        set_name_text = card.bond_name or '',
        progress_text = selected and selected.progress_text or '',
        icon_res = resolved_icon,
        item_name_text = card.name or '技能卡牌',
        current_text = card.desc or '',
        effect_text = display_effect_text,
        effect_body_text = display_effect_body,
      })
      card_entries[#card_entries + 1] = new_choice_entry({
        index = index,
        modifier_card_id = card.id,
        display_name = card.name,
        pretty_display_name = card.name,
        title = card.name,
        subtitle_text = card.name,
        icon_res = resolved_icon,
        icon = resolved_icon,
        ui_icon = resolved_icon,
        bg = card.bg,
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
      })
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
  return false, '旧仙缘节点系统已停用，请使用 debug_grant_modifier_card。'
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

  if is_bond_slots_full(runtime) then
    local entries = get_owned_bond_entries(state)
    if #entries > 0 then
      local oldest = entries[1]
      runtime.modifier_card_ids[oldest.node_id] = nil
      runtime.modifier_card_attr_bonuses[oldest.node_id] = nil
      runtime.modifier_card_effect_ids[oldest.node_id] = nil
      local new_owned = {}
      for _, owned_id in ipairs(runtime.owned_node_order or {}) do
        if owned_id ~= oldest.node_id then
          new_owned[#new_owned + 1] = owned_id
        end
      end
      new_owned[#new_owned + 1] = card.id
      runtime.owned_node_order = new_owned
      runtime.modifier_card_ids[card.id] = true
      runtime.modifier_card_attr_bonuses[card.id] = copy_bonus_pack(card.attr_pack or {})
      if card.extra_skill_desc and card.extra_skill_desc ~= '' and card.extra_skill_desc ~= '无' then
        runtime.modifier_card_effect_ids[card.id] = true
        BondModifierEffects.ensure_effect_state(runtime, card.bond_name)
      end
      sync_attr_bonuses_to_hero(env)
      return true, string.format('已替换获得单卡效果：%s（%s），被替换：%s。', tostring(card.name or card.id), tostring(card.bond_name or '未知技能'), oldest.display_name)
    end
    return false, '羁绊槽位已满且无现有羁绊可替换。'
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
M.get_bond_replacement_info = function(state)
  local runtime = ensure_runtime(state)
  if not runtime or not runtime.awaiting_bond_replacement then
    return nil
  end
  local pending_card = runtime.pending_bond_replacement_card
  if not pending_card then
    return nil
  end
  return {
    awaiting = true,
    new_card = {
      id = pending_card.id,
      name = pending_card.name or pending_card.bond_name or '未知卡牌',
      bond_name = pending_card.bond_name or '未知技能',
      quality = pending_card.quality or 'rare',
      icon = resolve_display_icon(pending_card.icon, pending_card.bg),
    },
    options = runtime.bond_replacement_options or {},
  }
end

return M
